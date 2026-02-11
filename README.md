# WILD 
Roblox 서바이벌 크래프팅 게임 프로젝트

이 프로젝트는 **Rojo + VS Code + GitHub + Team Create** 구조로 개발됩니다.

---

#  개발 방식 

## 역할 분리

###  코드 → GitHub + VS Code + Rojo
- 서버 로직
- 클라이언트 스크립트
- 모듈 / 리모트
- 모든 Lua 코드

###  맵 / UI / 에셋 → Roblox Studio (Team Create)
- Terrain
- Models
- Lighting
- StarterGui (UI)
- 맵 배치

 **코드는 Git 관리 / 맵은 Studio 관리**
 서로 절대 섞지 않음

---

#  프로젝트 구조
ㅇㅋ.
그냥 아래 그대로 전부 복붙해서 README.md 덮어써.
한국어 + 실전용 + Rojo/Git/Studio 워크플로우 기준으로 깔끔하게 정리해놨다.

# WILD 
Roblox 서바이벌 크래프팅 게임 프로젝트

이 프로젝트는 **Rojo + VS Code + GitHub + Team Create** 구조로 개발됩니다.

---

## 역할 분리

###  코드 → GitHub + VS Code + Rojo
- 서버 로직
- 클라이언트 스크립트
- 모듈 / 리모트
- 모든 Lua 코드

###  맵 / UI / 에셋 → Roblox Studio (Team Create)
- Terrain
- Models
- Lighting
- StarterGui (UI)
- 맵 배치

 **코드는 Git 관리 / 맵은 Studio 관리**
 서로 절대 섞지 않음

---

#  프로젝트 구조



WILD/
src/
server/ 서버 코드
client/ 클라이언트 코드
shared/ 공용 모듈/리모트

default.project.json
README.md


---

#  Rojo 동기화 구조 (자동 생성)

Studio 안에서 이렇게 생김:



ServerScriptService
└ Code
└ Server

StarterPlayerScripts
└ Code
└ Client

ReplicatedStorage
└ Code
└ Shared


 Code 폴더 안은 **절대 Studio에서 수정 금지**
→ VS Code가 원본

---
#  실행 방법

## 1️ Rojo 서버 실행
프로젝트 루트에서:

```powershell
.\rojo serve


정상:

Address: localhost
Port: xxxx

2️ Studio 연결

Studio → Plugins → Rojo → Connect → Accept

3️ 확인

VS Code 저장 → Studio 자동 반영
Play → print 로그 나오면 성공

 개발 워크플로우
코드 작업

VS Code에서 수정

저장

Studio 자동 동기화

테스트

git commit + push

맵/UI 작업

Studio에서 수정

Team Create 자동 저장
