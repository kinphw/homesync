// 우리집일정표 Cloud Functions
// 새 일정이 등록되면, 그 그룹의 구성원(작성자 제외)에게 FCM 푸시를 보낸다.
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {setGlobalOptions} = require("firebase-functions/v2");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

initializeApp();
setGlobalOptions({region: "asia-northeast3", maxInstances: 5});

const PERIOD_LABEL = {
  allDay: "종일",
  morning: "오전",
  afternoon: "오후",
  evening: "저녁",
};

exports.onNewEvent = onDocumentCreated(
    "groups/{groupId}/events/{eventId}",
    async (event) => {
      const snap = event.data;
      if (!snap) {
        console.log("스냅샷 없음 → 중단");
        return;
      }
      const data = snap.data();
      const groupId = event.params.groupId;
      const db = getFirestore();
      console.log(
          `새 일정: group=${groupId}, title=${data.title}, ` +
        `owner=${data.ownerName}(${data.ownerUid})`,
      );

      // 그룹 구성원 조회
      const groupDoc = await db.doc(`groups/${groupId}`).get();
      const group = groupDoc.data();
      if (!group) {
        console.log(`그룹 문서 없음: ${groupId} → 중단`);
        return;
      }
      const memberUids = group.memberUids || [];
      const ownerUid = data.ownerUid;
      console.log(`구성원 ${memberUids.length}명: ${memberUids.join(", ")}`);

      // 작성자를 제외한 구성원들의 FCM 토큰 수집
      const tokens = [];
      const tokenOwner = {}; // token -> uid (무효 토큰 정리용)
      await Promise.all(
          memberUids
              .filter((uid) => uid !== ownerUid)
              .map(async (uid) => {
                const u = (await db.doc(`users/${uid}`).get()).data();
                (u && u.fcmTokens ? u.fcmTokens : []).forEach((t) => {
                  tokens.push(t);
                  tokenOwner[t] = uid;
                });
              }),
      );
      console.log(`받는 사람 토큰 ${tokens.length}개`);
      if (tokens.length === 0) {
        console.log("받을 토큰 없음(작성자 제외 구성원이 앱 로그인/알림허용 안 함?) → 중단");
        return;
      }

      // 알림 문구
      const periodLabel = PERIOD_LABEL[data.period] || "";
      let dateStr = "";
      if (data.date && typeof data.date.toDate === "function") {
        const d = data.date.toDate();
        dateStr = `${d.getMonth() + 1}/${d.getDate()}`;
        // 기간 일정이면 종료일까지 표시
        if (data.endDate && typeof data.endDate.toDate === "function") {
          const e2 = data.endDate.toDate();
          if (e2 > d) {
            dateStr += `~${e2.getMonth() + 1}/${e2.getDate()}`;
          }
        }
      }
      const title = `${data.ownerName || "가족"}님이 일정을 등록했어요`;
      const body = `${dateStr} ${periodLabel} ${data.title || ""}`.trim();

      const res = await getMessaging().sendEachForMulticast({
        tokens,
        notification: {title, body},
        android: {
          priority: "high",
          notification: {channelId: "event_reminders"},
        },
      });
      console.log(
          `전송 완료: 성공=${res.successCount}, 실패=${res.failureCount} ` +
        `| "${title}" / "${body}"`,
      );
      res.responses.forEach((r, i) => {
        if (!r.success) {
          console.log(`  실패[${i}]: ${r.error && r.error.code}`);
        }
      });

      // 무효(만료/삭제) 토큰 정리
      const toRemove = {}; // uid -> [token]
      res.responses.forEach((r, i) => {
        if (!r.success) {
          const code = (r.error && r.error.code) || "";
          if (
            code.includes("registration-token-not-registered") ||
            code.includes("invalid-argument")
          ) {
            const t = tokens[i];
            const uid = tokenOwner[t];
            (toRemove[uid] = toRemove[uid] || []).push(t);
          }
        }
      });
      await Promise.all(
          Object.entries(toRemove).map(([uid, ts]) =>
            db.doc(`users/${uid}`).update({
              fcmTokens: FieldValue.arrayRemove(...ts),
            }),
          ),
      );
    },
);
