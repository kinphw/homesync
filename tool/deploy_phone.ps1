# 연결된 안드로이드 폰에 release APK를 빌드해서 바로 설치한다.
# 안드로이드 스튜디오 없이, VS Code 태스크 또는 터미널에서 실행:
#   powershell -ExecutionPolicy Bypass -File tool/deploy_phone.ps1
$ErrorActionPreference = "Stop"
# 한글 출력이 깨지지 않도록 콘솔 출력 인코딩을 UTF-8로.
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$adb     = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$flutter = "C:\dev\flutter\bin\flutter.bat"
$apk     = "build\app\outputs\flutter-apk\app-release.apk"
$pkg     = "com.sncmlife.homesync"

# 1) 연결된 안드로이드 기기(=adb에 'device' 상태) 찾기
$dev = (& $adb devices | Select-String "device$" |
        ForEach-Object { ($_ -split "\s+")[0] } | Select-Object -First 1)
if (-not $dev) {
  Write-Host "[X] 폰이 연결돼 있지 않습니다." -ForegroundColor Red
  Write-Host "    USB 케이블로 연결하고 폰에서 'USB 디버깅 허용'을 눌러주세요." -ForegroundColor Yellow
  Write-Host "    (무선 디버깅을 쓰면 idle 시 자주 끊깁니다 — USB 권장)" -ForegroundColor Yellow
  exit 1
}
Write-Host "[i] 대상 기기: $dev" -ForegroundColor Cyan

# 2) release APK 빌드
Write-Host "[i] release APK 빌드 중... (몇 분 걸릴 수 있어요)" -ForegroundColor Cyan
& $flutter build apk --release
if ($LASTEXITCODE -ne 0) { Write-Host "[X] 빌드 실패" -ForegroundColor Red; exit 1 }

# 3) 설치 (서명 충돌 시 자동으로 제거 후 재설치)
Write-Host "[i] 설치 중..." -ForegroundColor Cyan
& $adb -s $dev install -r $apk
if ($LASTEXITCODE -ne 0) {
  Write-Host "[!] 덮어쓰기 실패(서명 불일치 가능) → 기존 앱 제거 후 재설치합니다." -ForegroundColor Yellow
  & $adb -s $dev uninstall $pkg | Out-Null
  & $adb -s $dev install $apk
  if ($LASTEXITCODE -ne 0) { Write-Host "[X] 설치 실패" -ForegroundColor Red; exit 1 }
}

# 4) 앱 실행
& $adb -s $dev shell monkey -p $pkg -c android.intent.category.LAUNCHER 1 | Out-Null
Write-Host "[OK] 설치 완료! 폰에서 '우리집일정표'가 실행됩니다." -ForegroundColor Green
