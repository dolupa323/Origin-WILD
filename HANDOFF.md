# WILD Roblox Engine - Phase 1-2 인수인계 문서

**작성일:** 2026-02-12  
**현재 상태:** Phase 1-2 Crafting System ✅ PASS  
**담당자:** AI Assistant (GitHub Copilot)

---ㅁ

## 📋 Executive Summary

WILD는 Roblox 생존 게임 엔진으로, 엄격한 서버 권한 부여(Server Authoritative), 데이터 주도(Data-Driven) 아키텍처를 따릅니다.

- **Phase 0** (완료): 9개 서비스 + AI 프레임워크 (Net, Entity, Inventory, Combat, Effects, Equip, Drop, Interact, Save)
- **Phase 1-1** (완료): ResourceNode 채전 시스템 (E키 상호작용, 드롭 통합)
- **Phase 1-2** (완료): Crafting System (레시피 검증, ATOMIC 거래 의미론, 아이템 소비/지급)

---

## 🏗️ 아키텍처 원칙

### 1. Server Authoritative

- **모든 상태 변경은 서버에서만 발생**
- 클라이언트는 요청만 전송, 검증은 서버가 담당
- 치팅/글리칭 방지

### 2. Data Driven

- 외부 설정 파일들이 로직과 분리:
  - `ItemDB.lua` - 아이템 정의 (MaxStack, Type)
  - `RecipeDB` (CraftingService 내) - 레시피 정의
  - `Types.lua` - 플레이어 세이브 구조
- 로직은 데이터를 읽기만 함

### 3. ATOMIC Transaction Semantics

- **검증 → 소비 → 지급** 순서 엄격함
- 출력이 들어갈 공간을 소비 **전에** 예검증
- 부분 실패 불가 (모두 성공 또는 모두 실패)

### 4. Add-Only Phases

- 완료된 Phase는 절대 리팩토링 목금지
- 새 Phase는 기존 서비스에 핸들러/디스패처만 추가
- 이유: 기존 기능 안정성 보장

---

## 📁 디렉토리 구조 (Rojo 매핑)

```
src/
├── client/
│   ├── client_init.lua → StarterPlayer.StarterCharacterScripts.Code.Client.client_init
│   └── crafting_test.client.lua → crafting_test.client (모듈)
├── server/
│   ├── server_init.lua → ServerScriptService.Code.Server.server_init
│   ├── Bootstrap.server.lua
│   └── Services/
│       ├── SaveService.lua (DataStore 영속성)
│       ├── InventoryService.lua (슬롯 관리)
│       ├── EquipService.lua (장비 장착)
│       ├── InteractService.lua (상호작용 디스패치)
│       ├── DropService.lua (아이템 드롭)
│       ├── EffectService.lua (시각 효과)
│       ├── CombatSystem.lua (전투)
│       ├── AIService.lua (AI 프레임워크)
│       ├── CraftingService.lua ⭐ Phase 1-2
│       ├── ResourceNodeService.lua (Phase 1-1)
│       └── Systems/ (미래 확장)
└── shared/
    ├── Net.lua (RemoteEvent 래퍼)
    ├── ItemDB.lua ⭐ (아이템 데이터)
    ├── Types.lua (세이브 스키마)
    ├── Tags.lua (CollectionService 태그)
    ├── Attr.lua (속성 상수)
    ├── Contracts/
    │   ├── Contracts_Crafting.lua ⭐ (에러 코드, Remotes)
    │   ├── Contracts_Interact.lua
    │   └── Contracts_Equip.lua
    └── Equip/
        ├── EquipRegistry.lua (장비 동적 로드)
        └── EquipItems/ (장비 시각 효과 모듈)
```

---

## 🔧 Phase 1-2 Crafting System (상세)

### 시스템 개요

**목표:** 플레이어가 워크벤치 근처에서 레시피를 소모

- 재료 소비 → 제작 완료 → 산출물 지급

### 핵심 파일

#### 1️⃣ `CraftingService.lua`

```lua
-- 함수
- OpenBench(player, benchInstance)
  └─ lastBenchAt[userId] = {bench, t} 기록 (5초 유효기간)

- HandleCraftRequest(player, payload) → {rid, ok, code, msg, data}
  ├─ 레시피 존재 검증
  ├─ 벤치 컨텍스트 검증 (유효기간, 거리 ≤12 스터드)
  ├─ 재료 충분함 검증
  ├─ 출력 공간 적합성 검증 (NEW: 원자성 보장)
  ├─ 재료 소비 (InventoryService.AddItem(player, id, -qty))
  ├─ 산출물 지급 (InventoryService.AddItem(player, id, qty))
  └─ 응답: ok=true code=OK OR ok=false code={NOT_FOUND|VALIDATION_FAILED|DENIED|...}

-- 내부 헬퍼
- canFitOutputs(player, recipe) → bool
  └─ 레시피 출력이 현재 인벤토리에 들어가는가?
  └─ 스택 공간 + 빈 슬롯 계산

-- RecipeDB (인라인)
{
  StoneAxe = {inputs={{id="Wood", qty=3}, {id="Stone", qty=2}}, outputs={{id="StoneAxe", qty=1}}},
  StonePickaxe = {inputs={{id="Wood", qty=2}, {id="Stone", qty=3}}, outputs={{id="StonePickaxe", qty=1}}},
}
```

#### 2️⃣ `ItemDB.lua` ⭐ 중요

```lua
return {
  Wood = {MaxStack=100, Type="Resource"},
  Stone = {MaxStack=100, Type="Resource"},
  Pickaxe = {MaxStack=1, Type="Equipment"},
  StoneAxe = {MaxStack=1, Type="Equipment"},     -- ⭐ 추가됨
  StonePickaxe = {MaxStack=1, Type="Equipment"}, -- ⭐ 추가됨
}
```

**주의:** RecipeDB의 모든 입출력 아이템이 반드시 ItemDB에 정의되어야 함

#### 3️⃣ `Contracts_Crafting.lua`

```lua
C.Error = {
  OK, VALIDATION_FAILED, NOT_ENOUGH_ITEMS, INVENTORY_FULL,
  DENIED, NOT_FOUND, OUT_OF_RANGE, COOLDOWN, INTERNAL_ERROR
}

C.Remotes = {"Craft_Request", "Craft_Ack"}
```

#### 4️⃣ `InventoryService.lua` ⭐ 확장됨

```lua
- AddItem(player, itemId, qty) → bool
  ├─ qty < 0 → RemoveItem(player, itemId, -qty) 호출
  ├─ qty > 0 → 스택/빈슬롯에 추가
  └─ 반환: 전부 추가 성공 시 true, 부분만 추가되거나 실패 시 false

- RemoveItem(player, itemId, qty) → bool
  ├─ 기존 스택에서 qty만큼 제거
  ├─ 스택이 비면 슬롯 nil 설정
  └─ 반환: 전부 제거 성공 시 true
```

#### 5️⃣ `InteractService.lua` (수정: add-only)

```lua
handlers.CraftBench = function(player, target, hit, distance)
  local ok = CraftingService.OpenBench(player, target)
  return ok, nil
end

-- 기존 handlers는 절대 수정 금지
```

#### 6️⃣ `client_init.lua` (수정)

```lua
-- Infinite yield 방지 패턴
local folder = script.Parent
local m = folder:FindFirstChild("crafting_test")
    or folder:FindFirstChild("crafting_test.client")
    or folder:FindFirstChild("crafting_test.client.lua")

if m then
    require(m)
else
    warn("[client_init] crafting_test module not found")
end
```

#### 7️⃣ `server_init.lua` (테스트 하네스)

```lua
task.delay(7, function()
  -- 1. 인벤토리 초기화 (이전 데이터 제거)
  local inv = SaveService.Get(player).Inventory.Slots
  for i=1,30 do inv[i] = nil end

  -- 2. 최소 재료 추가
  InventoryService.AddItem(player, "Wood", 3)
  InventoryService.AddItem(player, "Stone", 2)

  -- 3. 테스트 벤치 생성
  bench:SetAttribute("InteractType", "CraftBench")
  CollectionService:AddTag(bench, "Interactable")
end)
```

---

## 🔄 통신 흐름 (ATOMIC 패턴)

### Client → Server 요청

```
Craft_Request {
  rid = "12345-1234.567",
  t = os.clock(),
  data = {
    recipeName = "StoneAxe"
  }
}
```

### Server 처리 (ATOMIC)

```
1️⃣ 레시피 존재? ✓
   → RecipeDB["StoneAxe"] 찾기

2️⃣ 벤치 컨텍스트 유효? ✓
   → lastBenchAt[userId] 체크
   → 유효기간 (5초) 체크
   → 거리 (≤12 스터드) 체크

3️⃣ 재료 충분? ✓
   → InventoryService.GetSlots() 반복
   → Wood ≥3, Stone ≥2 확인

4️⃣ 출력 공간? ✓ ⭐ 원자성 핵심
   → canFitOutputs(player, recipe) 호출
   → 실패 시 INVENTORY_FULL 반환 (재료 미 소비)

5️⃣ 모두 통과했으면 GO:
   → AddItem(player, "Wood", -3)    // 소비
   → AddItem(player, "Stone", -2)   // 소비
   → AddItem(player, "StoneAxe", 1) // 지급
   → ok=true code=OK 응답
```

### Server → Client 응답

```
Craft_Ack {
  rid = "12345-1234.567",
  ok = true|false,
  code = "OK"|"NOT_ENOUGH_ITEMS"|"INVENTORY_FULL"|...,
  msg = nil|"need Wood x3",
  data = {recipe="StoneAxe"} (성공 시)
}
```

---

## ⚠️ 중요 설계 결정 & 주의사항

### 1. RemoveItem 구현 방식

```lua
-- ❌ 잘못된 방식 (SaveService 직접 조작)
SaveService.Get(player).Inventory.Slots[i].Qty -= qty

-- ✅ 올바른 방식 (InventoryService API)
InventoryService.RemoveItem(player, itemId, qty)
-- 또는
InventoryService.AddItem(player, itemId, -qty)
```

**이유:** SaveService 직접 조작 시 다음 위험:

- 핫바/장착 아이템과 동기화 깨짐
- 아이템 중복 가능성
- 향후 migration 어려움

### 2. ATOMIC 트랜잭션 순서

```lua
-- ❌ 위험한 순서 (원자성 위반)
consume(Wood x3)
if not canFit(outputs) then
  -- 이미 소비했으므로 롤백 필요 → 복잡함
  rollback()
end
grant(outputs)

-- ✅ 안전한 순서 (원자성 보장)
if not canFit(inputs) return ERROR
if not canFit(outputs) return ERROR  -- ⭐ 소비 전 검증
consume_all()
grant_all()
```

### 3. Bench Context 5초 유효기간

- 플레이어가 벤치를 떠났을 때 오래된 컨텍스트로 원격 제작 방지
- 시간이 아니라 거리로도 검증 (≤12 스터드)
- 둘 다 통과할 때만 제작 허용

### 4. ItemDB 누락 → canFitOutputs 실패

```lua
-- ItemDB에 StoneAxe가 없으면
local def = ItemDB["StoneAxe"] -- nil
if not def then return false    -- 출력 불능
```

**해결:** ItemDB와 RecipeDB 항상 동기화 필요

---

## 🧪 DoD (Definition of Done) 검증 항목

### Phase 1-2 완료 조건 (모두 PASS)

- ✅ Client infinite yield 제거 (WaitForChild 안전화)
- ✅ ATOMIC 트랜잭션 (소비 전 검증)
- ✅ INVENTORY_FULL 에러 코드 (원자성 증명)
- ✅ 성공 로그: `[Crafting] consume ... grant ... [Craft_Ack] ok=true code=OK`
- ✅ 실패 로그: `[Craft_Ack] ok=false code=NOT_ENOUGH_ITEMS`
- ✅ 거리 검증 + 컨텍스트 만료 검증
- ✅ InventoryService API만 사용 (SaveService 직접 접근 X)

**마지막 테스트 로그:**

```
16:18:30.603 [Crafting] canFitOutputs: all outputs fit ✓
16:18:30.603 [Crafting] consume Wood x3
16:18:30.604 [Crafting] consume Stone x2
16:18:30.604 [Crafting] grant StoneAxe x1
16:18:30.636 [Craft_Ack] ok=true code=OK
```

---

## 🚀 다음 Phase 계획 (Phase 1-3 이상)

### 가능한 확장 방향

#### Option A: 진행 표시 (Progress Bar)

- 제작 시간: `recipe.time` 초 대기
- 클라는 UI 진행 표시 → 취소 가능
- 서버는 완료 후 grant
- 파일 추가: `ProgressService.lua`

#### Option B: 다중 출력 레시피

- 확률 기반 산출물 (예: 성공률 80%)
- 크리티컬 제작 (보너스 출력)
- RecipeDB 확장: `outputs` → 배열 대신 `{outputs, critical_outputs}`

#### Option C: NPC 거래

- Merchant NPC 추가
- Buy/Sell 컨트랙트
- Trading UI

#### Option D: 기술 트리 (앞으로 필요한 것)

- 특정 Perks/Skills 없으면 레시피 제작 불가
- Contracts_Crafting에 권한 검증 추가

### 리팩토링 금지 (우회 패턴)

```lua
-- Phase 1-2가 "추상 벤치" 기반이므로:

-- ❌ CraftingService.HandleCraftRequest 수정 금지
-- ✅ 대신 새 함수로 확장:
function CraftingService.HandleSpecialCraft(player, payload, options)
  -- 특별한 제작 로직 (예: 보너스 출력)
  -- 기존은 건드리지 않음
end
```

---

## 🐛 알려진 이슈 & 해결책

### 1. Client 모듈 로딩 불안정

**증상:** `Infinite yield possible on ... WaitForChild("crafting_test.client")`

**원인:** Rojo가 `.client.lua` 파일을 `crafting_test.client` 인스턴스로 매핑하는데, 클라이언트 부팅 시점에 아직 로드 안 된 상태

**해결:** 3단계 폴백 패턴

```lua
local m = folder:FindFirstChild("crafting_test")
    or folder:FindFirstChild("crafting_test.client")
    or folder:FindFirstChild("crafting_test.client.lua")
if m then require(m) else warn(...) end
```

### 2. InventoryService 음수 처리

**증상:** 제작 시 재료 소비 안 됨

**원인:** `AddItem(player, "Wood", -3)` 음수가 스택과 빈슬롯 로직에서 처리 안 됨

**해결:** 음수 감지 → `RemoveItem()` 위임

```lua
function InventoryService.AddItem(player, itemId, qty)
  if qty < 0 then
    return InventoryService.RemoveItem(player, itemId, -qty)
  end
  -- ... 양수 처리
end
```

### 3. 출력 공간 부족 감지 실패

**증상:** 빈 슬롯이 있어도 INVENTORY_FULL 반환

**원인:** ItemDB에 출력 아이템 정의 없음 → def=nil → canFit=false

**해결:** ItemDB와 RecipeDB 동기화 체크

```lua
-- CraftingService.RecipeDB에 있는 모든 아이템이
-- ItemDB에도 반드시 있어야 함
for _, recipe in pairs(RecipeDB) do
  for _, item in ipairs(recipe.inputs + recipe.outputs) do
    assert(ItemDB[item.id], item.id .. " missing in ItemDB")
  end
end
```

---

## 📊 서비스 간 의존성

```
CraftingService
├─ 의존: InventoryService (AddItem, GetSlots, RemoveItem)
├─ 의존: InteractService (실제로는 호출되지 않음, 디스패처 역할만)
├─ 의존: Net (Register, Fire)
├─ 의존: ItemDB (MaxStack 조회)
├─ 의존: Contracts_Crafting (에러 코드)
└─ 의존: SaveService (간접: InventoryService를 통해)

InteractService (Phase 1-2 수정)
├─ 의존: CraftingService.OpenBench (handlers.CraftBench에서 호출)
└─ 기존 handlers 수정 금지

InventoryService (Phase 1-2 확장)
├─ 의존: SaveService (슬롯 데이터)
├─ 의존: ItemDB (MaxStack)
└─ 새 함수 추가: RemoveItem

```

---

## 📝 로깅 컨벤션

### Crafting 관련 로그 포맷

```lua
print(("[Crafting] %s"):format(msg))
-- 예: [Crafting] OpenBench player=Player1 bench=...

print(("[%s] %s"):format(service, msg))
-- 예: [Craft_Ack] ok=true code=OK
```

### 디버그 레벨별

```lua
-- 1. 상태 전이
print(("[Crafting] %s"):format("OpenBench"))
print(("[Crafting] %s -> %s"):format("idle", "crafting"))

-- 2. 검증 통과
print(("[Crafting] canFitOutputs: %s"):format("all outputs fit ✓"))

-- 3. 데이터 변경
print(("[Crafting] consume %s x%d"):format(id, qty))
print(("[Crafting] grant %s x%d"):format(id, qty))

-- 4. 에러
print(("[Crafting] %s"):format("insufficient Wood: have=0 need=3"))
```

---

## ✅ 체크리스트 (미래 개발자용)

### Phase 1-3 시작 전 확인

- [ ] `src/server/server_init.lua` 의 Phase1-2 테스트 하네스 여전히 가용
- [ ] CraftingService, InteractService 코드 리뷰 완료
- [ ] ItemDB에 모든 아이템 정의 확인
- [ ] RecipeDB 추가할 때마다 ItemDB와 동기화 확인
- [ ] Contracts_Crafting 에러 코드 문서화
- [ ] InventoryService.RemoveItem 테스트

### 배포 전 확인

- [ ] 무한 yield 로그 없음
- [ ] PASS DoD 로그 캡처 (스크린샷 저장)
- [ ] SaveService 직접 접근 grep 검색 (CraftingService에서 0건)
- [ ] RemoveItem 호출 경로 전수 검사
- [ ] Net 계약 위반 케이스 테스트

---

## 📚 참고 자료

### 핵심 파일 요약

| 파일                   | 역할                                | Phase |
| ---------------------- | ----------------------------------- | ----- |
| CraftingService.lua    | 레시피 검증/소비/지급               | 1-2   |
| InventoryService.lua   | 슬롯 관리 (추가 RemoveItem)         | 1-2   |
| ItemDB.lua             | 아이템 메타 (추가 StoneAxe/Pickaxe) | 1-2   |
| Contracts_Crafting.lua | 계약 (추가 INVENTORY_FULL)          | 1-2   |
| InteractService.lua    | 디스패처 (추가 CraftBench 핸들러)   | 1-2   |
| client_init.lua        | 클라 부팅 (안전화 WaitForChild)     | 1-2   |

### 권장 학습 순서

1. `Net.lua` 읽기 → RemoteEvent 패턴 이해
2. `SaveService.lua` 읽기 → 영속성 메커니즘 이해
3. `InventoryService.lua` 읽기 → 슬롯 관리 로직
4. `CraftingService.lua` 읽기 → ATOMIC 트랜잭션
5. `InteractService.lua` 읽기 → 핸들러 디스패치 패턴

---

**최종 상태:** ✅ Phase 1-2 PASS  
**다음 단계:** Phase 1-3 또는 옵션 선택

문의사항이 있으면 로그와 함께 재점검하세요!
