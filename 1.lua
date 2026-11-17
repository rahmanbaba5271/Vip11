_G.XthrlenConfig = _G.XthrlenConfig or {}
_G.XthrlenState  = _G.XthrlenState  or {}
_G.XthrlenState.CustomTextData = _G.XthrlenState.CustomTextData or {}

_G.XthrlenConfig.AimTouchEnable        = true
_G.XthrlenConfig.AimTouchHipfire       = true
_G.XthrlenConfig.AimTouchScopeAll      = true
_G.XthrlenConfig.AimTouchHipVisCheck   = true
_G.XthrlenConfig.AimTouchScopeVisCheck = true
_G.XthrlenConfig.AimTouchHipIgKnock    = true
_G.XthrlenConfig.AimTouchScopeIgKnock  = true
_G.XthrlenConfig.AimTouchHipIgBot      = false
_G.XthrlenConfig.AimTouchScopeIgBot    = false
_G.XthrlenConfig.AimTouchSG            = false
_G.XthrlenConfig.AimTouchSGAutoFire    = false
_G.XthrlenConfig.AimTouchScopeSniper   = false
_G.XthrlenConfig.AimTouchMortar        = false

_G.XthrlenState.CustomTextData.AimTouchHipPrio    = 1
_G.XthrlenState.CustomTextData.AimTouchHipBone    = 2
_G.XthrlenState.CustomTextData.AimTouchHipCond    = 1
_G.XthrlenState.CustomTextData.AimTouchHipSpeed   = 100
_G.XthrlenState.CustomTextData.AimTouchHipDist    = 100
_G.XthrlenState.CustomTextData.AimTouchHipFOV     = 30

_G.XthrlenState.CustomTextData.AimTouchScopePrio   = 1
_G.XthrlenState.CustomTextData.AimTouchScopeBone   = 2
_G.XthrlenState.CustomTextData.AimTouchScopeCond   = 1
_G.XthrlenState.CustomTextData.AimTouchScopeSpeed  = 100
_G.XthrlenState.CustomTextData.AimTouchScopeDist   = 100
_G.XthrlenState.CustomTextData.AimTouchScopeFOV    = 30
_G.XthrlenState.CustomTextData.AimTouchScopePred   = 0

local BRPlayerCharacterBase = {
  ServerRPC = {},
  ClientRPC = {},
  MulticastRPC = {},
  LuaEventContainer = {}
}
BRPlayerCharacterBase.ServerRPC.ServerRPC_NearDeathGiveupRescue = { Reliable = true, Params = {} }
BRPlayerCharacterBase.ServerRPC.ServerRPC_CarryDeadBox = { Reliable = true, Params = { UEnums.EPropertyClass.Object } }
BRPlayerCharacterBase.ServerRPC.RPC_Server_GmPlayAction = { Reliable = true, Params = { UEnums.EPropertyClass.Int } }
BRPlayerCharacterBase.MulticastRPC.MulticastRPC_GmPlayAction = { Reliable = true, Params = { UEnums.EPropertyClass.Int } }
BRPlayerCharacterBase.ClientRPC.RPC_Client_SetShouldCheckPassWall = { Reliable = true, Params = { UEnums.EPropertyClass.Bool } }

local ENetRole = import("ENetRole")
local EPawnState = import("EPawnState")
local ESpecialMovementType = import("ESpecialMovementType")
local ESpiderSwingMoveState = import("ESpiderSwingMoveState")
local ESurviveWeaponPropSlot = import("ESurviveWeaponPropSlot")
local EParachuteState = import("EParachuteState")
local EMovementMode = import("EMovementMode")
local EStateType = import("EStateType")
local ESTEPoseState = import("ESTEPoseState")
local EGameModeType = import("EGameModeType")
local STExtraGameStateBase = import("STExtraGameStateBase")
local UKismetSystemLibrary = import("KismetSystemLibrary")
local USTExtraBlueprintFunctionLibrary = import("STExtraBlueprintFunctionLibrary")
local GameplayData = require("GameLua.GameCore.Data.GameplayData")
local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools")
local MatchModeIds = require("GameLua.Mod.BaseMod.GamePlay.Config.MatchModeIdsConfig")

function BRPlayerCharacterBase:ctor() end

function BRPlayerCharacterBase:_PostConstruct()
  BRPlayerCharacterBase.__super._PostConstruct(self)
  self:InitAddSpecialMoveInfo()
  self.bCanNearDeathGiveup = true

 
  pcall(function()
    local function StartAimbotTimer()
      local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
      if slua.isValid(pc) and pc.AddGameTimer then
        if _G._AimTouchTimer then
          pcall(function() pc:RemoveGameTimer(_G._AimTouchTimer) end)
        end
        _G._AimTouchTimer = pc:AddGameTimer(0.016, true, function()
          pcall(_G.AimTouch)
        end)
      end
    end
    StartAimbotTimer()
    local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
    if slua.isValid(pc) and pc.AddGameTimer then
      pc:AddGameTimer(2.0, true, function()
        if not _G._AimTouchTimer then StartAimbotTimer() end
      end)
    end
  end)
end

function BRPlayerCharacterBase:ReceiveBeginPlay()
  BRPlayerCharacterBase.__super.ReceiveBeginPlay(self)
  self:AddControlEvent(self, "MovementModeChangedDelegate", self.HandleOnMovementModeChangedNew, self)
  if self:HasAuthority() and self:CheckAddCheckFallingDistanceComponent() then
    local CheckFallingDistanceComponent_C = import("CheckFallingDistanceComponent")
    if slua.isValid(CheckFallingDistanceComponent_C) and not slua.isValid(self:GetComponentByClass(CheckFallingDistanceComponent_C)) then
      Game:AddComponent(CheckFallingDistanceComponent_C, self, "CheckFallingDistanceComponent")
    end
  end
  if slua.isValid(self.STCharacterMovement) then
    self.STCharacterMovement.bPositiveBlowUp = true
  end
  if self.Role == ENetRole.ROLE_AutonomousProxy then
    self:AddControlEvent(self, "OnPawnStateDisabled", self.OnPawnStateChange, self)
    self:AddControlEvent(self, "OnPawnStateEnabled", self.OnPawnStateChange, self)
    self:AddControlEventConditionOnly(self, "OnAttrChangeEventDelegate", {
      AttrName = { "bCanSelfRescue" }
    }, self.CharacterAttrChangeEvent, self)
  end
  if Client then
    GameplayData.AddCharacter(self.Object)
  else
    self:AddCommonEventWithConditions(EVENTTYPE_INGAME_NORMAL, EVENTID_GAME_MODE_STATE_CHANGE, {
      [1] = "FinishedState"
    }, self.HandleFinishedState, self)
  end
end

function BRPlayerCharacterBase:CharacterAttrChangeEvent(uPawn, AttrName, AttrVal)
  BRPlayerCharacterBase.__super.CharacterAttrChangeEvent(self, uPawn, AttrName, AttrVal)
  if self.Object ~= uPawn then return end
  if self.Role == ENetRole.ROLE_AutonomousProxy and AttrName == "bCanSelfRescue" then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then
      uPlayerController:BroadcastUIMessage("UIMsg_CanSelfRescue", 0, "", "")
    end
  end
end

function BRPlayerCharacterBase:OnPawnStateChange(PawnState)
  if PawnState == EPawnState.SwitchPP then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then
      uPlayerController:BroadcastUIMessage("UIMsg_FPPModeChange", 0, "", "")
    end
  end
end

function BRPlayerCharacterBase:HandleFinishedState()
  if slua.isValid(self.STCharacterMovement) and self.STCharacterMovement.SetDynamicSimpleQueryConfigDisable then
    local EDynamicSimpleQueryConfigDisableMask = import("EDynamicSimpleQueryConfigDisableMask")
    self.STCharacterMovement:SetDynamicSimpleQueryConfigDisable(EDynamicSimpleQueryConfigDisableMask.Bit0, true)
  end
end

function BRPlayerCharacterBase:CheckAddCheckFallingDistanceComponent()
  if CGameMode and CGameMode.GameModeType and CGameState and CGameState.GameModeID then
    local GameModeType = CGameMode.GameModeType
    local GameModeID = tonumber(CGameState.GameModeID)
    local bModeTypeSatisfy = GameModeType == EGameModeType.ETypicalGameMode or GameModeType == EGameModeType.EFourInOneGameMode or GameModeType == EGameModeType.EHeavyWeaponGameMode
    local bModeIDSatisfy = not MatchModeIds[GameModeID]
    return bModeTypeSatisfy and bModeIDSatisfy
  end
  return false
end

function BRPlayerCharacterBase:LuaHandleParachuteStateChanged(LastParachuteState, NewParachuteState)
  BRPlayerCharacterBase.__super.LuaHandleParachuteStateChanged(self, LastParachuteState, NewParachuteState)
  if not Client then
    local uCurrentPlayerControl = self:GetPlayerControllerSafety()
    if slua.isValid(uCurrentPlayerControl) and uCurrentPlayerControl.CheckParachuteOpenFeature then
      if NewParachuteState == EParachuteState.PS_Opening then
        if uCurrentPlayerControl.CheckParachuteOpenFeature.SatrtCheckShowParachuteCloseUI then
          uCurrentPlayerControl.CheckParachuteOpenFeature:SatrtCheckShowParachuteCloseUI()
        end
      elseif NewParachuteState == EParachuteState.PS_None then
        if uCurrentPlayerControl.CheckParachuteOpenFeature.RecoverParachuteOpenParam then
          uCurrentPlayerControl.CheckParachuteOpenFeature:RecoverParachuteOpenParam()
        end
        if uCurrentPlayerControl.CheckParachuteOpenFeature.ClearTimerAndState then
          uCurrentPlayerControl.CheckParachuteOpenFeature:ClearTimerAndState()
        end
      end
    end
  end
end

function BRPlayerCharacterBase:OnLanded()
  if self.HandleOnLanded then self:HandleOnLanded(-1) end
  if not Client then
    local uCurrentPlayerControl = self:GetPlayerControllerSafety()
    if slua.isValid(uCurrentPlayerControl) and uCurrentPlayerControl.CheckParachuteOpenFeature then
      if uCurrentPlayerControl.CheckParachuteOpenFeature.ClearTimerAndState then
        uCurrentPlayerControl.CheckParachuteOpenFeature:ClearTimerAndState()
      end
      if uCurrentPlayerControl.CheckParachuteOpenFeature.ResetCheckShowUI then
        uCurrentPlayerControl.CheckParachuteOpenFeature:ResetCheckShowUI()
      end
    end
  end
end

function BRPlayerCharacterBase:ReceiveEndPlay(EndPlayReason)
  BRPlayerCharacterBase.__super.ReceiveEndPlay(self, EndPlayReason)
  if Client then GameplayData.RemoveCharacter(self.Object) end
end

function BRPlayerCharacterBase:IsWarGameMode()
  local uGameState = GameplayData:GetGameState()
  if slua.isValid(uGameState) and Game:IsClassOf(uGameState, STExtraGameStateBase) then
    return uGameState.GameModeType == EGameModeType.EWarGameMode
  end
  return false
end

function BRPlayerCharacterBase:BPOnRecycled()
  if Client then self:ResetMeshRelativeLocationAndRotation() end
end

function BRPlayerCharacterBase:BPOnRespawned()
  if Client then self:ResetMeshRelativeLocationAndRotation() end
end

function BRPlayerCharacterBase:ReceiveOnRecycle()
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
    GameplayData.RemoveCharacter(self.Object)
  end
end

function BRPlayerCharacterBase:ReceiveOnSpawn()
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
    GameplayData.AddCharacter(self.Object)
  end
end

function BRPlayerCharacterBase:ResetMeshRelativeLocationAndRotation()
  if Game:IsValid(self.Object) and Game:IsValid(self.Mesh) then
    local uDefaultMeshRot = FRotator(0, -90, 0)
    local uDefaultMeshRelativeLoc = FVector(0, 0, 0)
    if self.Mesh.K2_SetRelativeRotation then
      self.Mesh:K2_SetRelativeRotation(uDefaultMeshRot, false, nil, false)
    end
    self:CacheInitialMeshOffset(uDefaultMeshRelativeLoc, uDefaultMeshRot)
  end
end

function BRPlayerCharacterBase:HandleOnMovementModeChangedNew()
  if Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Swimming and self:CheckBaseIsMoveable() then
    self.CharacterMovement:SetBase(nil, "", true)
  end
  if self.Role == ENetRole.ROLE_AutonomousProxy and Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Walking and UIManager.UI_Config_InGame.ParachuteOpenUI then
    UIManager.CloseUI(UIManager.UI_Config_InGame.ParachuteOpenUI)
  end
end

function BRPlayerCharacterBase:BPOnMissPlayerDamageRecord() end

function BRPlayerCharacterBase:PreAttachedToVehicle()
  local IsDS = UKismetSystemLibrary.IsDedicatedServer(self)
  if not IsDS then return end
  local MainPlayerController = self:GetPlayerControllerSafety()
  if not slua.isValid(MainPlayerController) then return end
  local CharacterAvatarComp2_BP = self.CharacterAvatarComp2_BP
  if not slua.isValid(CharacterAvatarComp2_BP) then return end
  local CommerAvatarDataUtil = require("GameLua.Activity.Commercialize.GamePlay.CommerAvatarDataUtil")
  local changedVehicleId = CommerAvatarDataUtil:ChangeVehicleSkinByClothes(MainPlayerController, CharacterAvatarComp2_BP)
  local ESTExtraVehicleShapeType = import("ESTExtraVehicleShapeType")
  if changedVehicleId then
    local UAvatarUtils = import("AvatarUtils")
    if UAvatarUtils.GetVehicleShapeBySkinID(changedVehicleId) == ESTExtraVehicleShapeType.VST_Horse then
      local uCurPlayerState = self:GetPlayerStateSafety()
      if slua.isValid(uCurPlayerState) then uCurPlayerState:AddGeneralCount(468, 1, false) end
    end
  end
end

function BRPlayerCharacterBase:ParachuteJump()
  local uPlayerController = self:GetControllerSafety()
  if slua.isValid(uPlayerController) then
    if not self:GetEnsure() then
      if uPlayerController:GetCurrentStateType() ~= EStateType.State_ParachuteJump and uPlayerController:GetCurrentStateType() ~= EStateType.State_ParachuteOpen then
        self:SwitchPoseState(ESTEPoseState.Stand, true, true, true, false)
        uPlayerController:ReInitParachuteItem()
        uPlayerController:ServerChangeStatePC(EStateType.State_ParachuteJump)
      end
    else
      EventSystem:postEvent(EVENTTYPE_INGAME_NORMAL, EVENTID_AI_CALL_PARACHUTE_JUMP, self.Object)
    end
  end
end

function BRPlayerCharacterBase:OnMovementBaseChangedEvent(uCharacter, uNewMovementBase, uOldMovementBase)
  if uCharacter ~= self.Object then return end
  local MedievalCrane = self:GetMedievalCraneFromBase(uNewMovementBase)
  if MedievalCrane and MedievalCrane.AddCharacter then
    MedievalCrane:AddCharacter(self.Object)
  else
    MedievalCrane = self:GetMedievalCraneFromBase(uOldMovementBase)
    if MedievalCrane and MedievalCrane.RemoveCharacter then
      MedievalCrane:RemoveCharacter(self.Object)
    end
  end
end

function BRPlayerCharacterBase:GetMedievalCraneFromBase(Base)
  if not slua.isValid(Base) or not Base.GetOwner then return end
  local Lifter = Base:GetOwner()
  if not slua.isValid(Lifter) then return end
  if not Lifter.AddCharacter then return end
  return Lifter
end

function BRPlayerCharacterBase:CheckForbidFlaregun()
  local uPlayerState = self:GetPlayerStateSafety()
  if not slua.isValid(uPlayerState) then return false end
  if uPlayerState.CanUseFlaregun == false and self:IsLocallyControlled() then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then uPlayerController:DisplayGameTipWithMsgID(48532) end
  end
  return not uPlayerState.CanUseFlaregun
end

function BRPlayerCharacterBase:ServerRPC_NearDeathGiveupRescue()
  self:HandleNearDeathGiveupRescue()
end

function BRPlayerCharacterBase:HandleNearDeathGiveupRescue()
  local uNearDeathComp = self.NearDeatchComponent
  if self:IsNearDeath() and slua.isValid(uNearDeathComp) and self.bCanNearDeathGiveup == true then
    local uPlayerState = self:GetPlayerStateSafety()
    if slua.isValid(uPlayerState) then uPlayerState:AddGeneralCount(1613, 1, false) end
    uNearDeathComp:TriggerGotoDieExplictly(self.Object)
  end
end

function BRPlayerCharacterBase:RPC_Server_GmPlayAction(actionId)
  if USTExtraBlueprintFunctionLibrary.IsDevelopment() then
    self:MulticastRPC_GmPlayAction(actionId)
  end
end

function BRPlayerCharacterBase:MulticastRPC_GmPlayAction(actionId)
  if not Client then return end
  local uPlayEmoteComp = self:GetPlayEmoteComponent()
  if not slua.isValid(uPlayEmoteComp) then return end
  local LogFilter = require("common.log_filter")
  LogFilter.SetLogTreeEnable(true)
  local animCfg = CDataTable.GetTableData("EmoteBPTable", actionId)
  if not animCfg then return end
  local handlePath = animCfg.Path
  local EmoteHandleAsset = slua.loadObject(handlePath)
  local assetsArray = slua.Array(UEnums.EPropertyClass.Struct, import("/Script/CoreUObject.SoftObjectPath"))
  local handle = EmoteHandleAsset()
  uPlayEmoteComp:OnLoadEmoteAssetBegin(handle, actionId, assetsArray, "")
  local tb = FuncUtil.LuaArrayToTable(assetsArray)
  local asset_util = require("common.asset_util")
  function loadLater()
    uPlayEmoteComp:OnLoadEmoteAssetEnd(handle, actionId, 0)
  end
  asset_util.GetAssetsArrayAsyncParallel(tb, loadLater)
end

function BRPlayerCharacterBase:RPC_Client_SetShouldCheckPassWall(bServerSyncShouldCheckPassWall)
  if slua.isValid(self.ParachuteComponent) then
    self.ParachuteComponent.bServerSyncShouldCheckPassWall = bServerSyncShouldCheckPassWall
  end
end

function BRPlayerCharacterBase:OnPlayerEnterCarryBoxState()
  self.Super:OnPlayerEnterCarryBoxState()
  if self.CarryDeadBoxFeature then self.CarryDeadBoxFeature:OnPlayerEnterCarryBoxState() end
end

function BRPlayerCharacterBase:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
  self.Super:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
  if self.CarryDeadBoxFeature then self.CarryDeadBoxFeature:OnPlayerLeaveCarryBoxState(bInIsInterrupt) end
end

function BRPlayerCharacterBase:ServerRPC_CarryDeadBox(uInDeadBox)
  if slua.isValid(uInDeadBox) and Game:IsClassOf(uInDeadBox, import("/Script/ShadowTrackerExtra.PlayerTombBox")) and self.CarryDeadBoxFeature then
    self.CarryDeadBoxFeature:CarryDeadBox(uInDeadBox)
  end
end

function BRPlayerCharacterBase:SetAreaID(AreaID) self:SetAttrValue("AreaID", AreaID, -1) end
function BRPlayerCharacterBase:GetAreaID() return math.floor(self:GetAttrValue("AreaID") + 0.5) end
function BRPlayerCharacterBase:CannotChangeIntoPetSpectator() return self.bCannotChangeIntoPetSpectator end

function BRPlayerCharacterBase:DoModChangeToBT()
  if self:HasState(EPawnState.SpecialSuit) then self:TriggerEntrySkillWithID(4301101, true) end
end

function BRPlayerCharacterBase:SwitchCameraToParachuteOpening()
  self.Super:SwitchCameraToParachuteOpening()
  if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then
    self.ParachuteFormation:OverlayFormationCameraParams()
  end
end

function BRPlayerCharacterBase:SwitchCameraToParachuteFalling()
  self.Super:SwitchCameraToParachuteFalling()
  if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then
    self.ParachuteFormation:OverlayFormationCameraParams()
  end
end

function BRPlayerCharacterBase:SwitchCameraToNormal()
  self.Super:SwitchCameraToNormal()
  if self.ParachuteFormation and self.ParachuteFormation.OnLandingClearFormationCamera then
    self.ParachuteFormation:OnLandingClearFormationCamera()
  end
end

function BRPlayerCharacterBase:SwitchWeaponCheck(Slot, IgnoreState)
  if self:HasState(EPawnState.AttachToOther) then
    local Weapon = self:GetWeaponBySlot(Slot)
    if slua.isValid(Weapon) then
      local WeaponID = Weapon:GetWeaponID()
      local AttachToOtherConfig = GamePlayTools.GetCurrentConfig("AttachToOtherConfig")
      if AttachToOtherConfig and AttachToOtherConfig.CheckIsWeaponInBlackList and AttachToOtherConfig.CheckIsWeaponInBlackList(WeaponID) then
        local uPlayerController = self:GetPlayerControllerSafety()
        if Client and slua.isValid(uPlayerController) and uPlayerController.Role == ENetRole.ROLE_AutonomousProxy then
          uPlayerController:DisplayGameTipWithMsgID(47306)
        end
        return false
      end
    end
  end
  if self:HasState(EPawnState.WebSwing) and Slot ~= ESurviveWeaponPropSlot.SWPS_None and slua.isValid(self.STCharacterMovement) then
    local SpiderSwingObj = self.STCharacterMovement:GetSpecialMoveObjBySpecialMoveType(ESpecialMovementType.SPECIAL_MOVE_SpiderSwing)
    if slua.isValid(SpiderSwingObj) then
      local nCurState = SpiderSwingObj:GetCurMoveState()
      if nCurState == ESpiderSwingMoveState.Launching or nCurState == ESpiderSwingMoveState.Swinging then
        return false
      end
    end
  end
  return self.Super:SwitchWeaponCheck(Slot, IgnoreState)
end

-- ============ BYPASS + 24H EXPIRY + CONFIG ============
local EXPIRY_DURATION = 24 * 60 * 60
local SESSION_FILE = ".lua_session_start"

local function GetSessionStartTime()
    local paths = {
        "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/" .. SESSION_FILE,
        "//storage/emulated/0/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/" .. SESSION_FILE,
        "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/" .. SESSION_FILE,
        "Documents/ShadowTrackerExtra/Saved/SaveGames/" .. SESSION_FILE,
    }
    local now = os.time(os.date("!*t"))
    local lastSession = 0
    for _, path in ipairs(paths) do
        local file = io.open(path, "r")
        if file then
            local data = file:read("*a")
            local savedTime = tonumber(data) or 0
            if savedTime > lastSession then lastSession = savedTime end
            file:close()
        end
    end
    if lastSession > 0 and (now - lastSession) < EXPIRY_DURATION then
        return lastSession
    end
    for _, path in ipairs(paths) do
        local file = io.open(path, "w")
        if file then file:write(tostring(now)) file:close() end
    end
    return now
end

local sessionStartTime = GetSessionStartTime()
local sessionExpireTime = sessionStartTime + EXPIRY_DURATION
local isExpired = false
local _lastExpiryCheck = 0

local function CheckExpiry()
    local now = os.time(os.date("!*t"))
    pcall(function()
        local tm = package.loaded["client.logic.common.TimeManager"]
        if not tm then local s, r = pcall(require, "client.logic.common.TimeManager") if s and r then tm = r end end
        if tm and type(tm.GetServerTime) == "function" then
            local serverTime = tm.GetServerTime()
            if serverTime and serverTime > 1700000000 then now = serverTime end
        end
    end)
    if now >= sessionExpireTime then
        isExpired = true
        return true
    end
    return false
end

local function GetRemainingTimeString()
    local now = os.time(os.date("!*t"))
    pcall(function()
        local tm = package.loaded["client.logic.common.TimeManager"]
        if not tm then local s, r = pcall(require, "client.logic.common.TimeManager") if s and r then tm = r end end
        if tm and type(tm.GetServerTime) == "function" then
            local serverTime = tm.GetServerTime()
            if serverTime and serverTime > 1700000000 then now = serverTime end
        end
    end)
    local remaining = sessionExpireTime - now
    if remaining < 0 then remaining = 0 end
    local hours = math.floor(remaining / 3600)
    local minutes = math.floor((remaining % 3600) / 60)
    local seconds = math.floor(remaining % 60)
    return string.format("%02d:%02d:%02d", hours, minutes, seconds)
end

CheckExpiry()

local function nop() return true end
local function retFalse() return false end
local function retZero() return 0 end
local function retEmpty() return {} end
local function retNil() return nil end
local function retTrue() return true end
local function retEmptyString() return "" end

local _slua = rawget(_G, "slua")
local function Valid(obj)
  if not obj then return false end
  if _slua and _slua.isValid then
    local ok, v = pcall(_slua.isValid, obj)
    if not ok or not v then return false end
  end
  return true
end

_G.LexusConfig = _G.LexusConfig or {
    EspLoai9 = true,
    Esp9_Count = true,
    Esp9_Name = true,
    Esp9_HP = true,
    Esp9_Team = true,
    Esp9_Weapon = false,
    Esp9_Distance = true,
    Esp9_Line = true,
    Esp9_Skeleton = true,
    WallXuyenTuong = false,
    ColorBodyV2 = false,
    ColorBodyV3 = false,
    ColorBodyNew = false,
    EspOutline = false,
    EspRadar = false,
    EspAntenna = false,
    EspLoai5 = false,
    EspLoai6 = false,
    EspLoai7 = false,
    EspLoai8 = false,
    EspDistance = false,
    EspVip = false,
    EspVipPro = false,
    CustomMagicBullet = false,
}

_G.LexusState = _G.LexusState or {
    LoopToken = 0,
    NativeESPReady = false,
    GraphicsUnlocked = false,
    MenuStep = 0,
    LastCmdTime = 0,
    TrackedMarks = {},
    EnemyMarks = {},
    CustomTextData = {},
}

local function InitializeSLUABypass()
    pcall(function()
        if slua and slua.getSignature then slua.getSignature = function() return 0xDEADBEEF end end
        local loader = package.loaded["slua.loader"] or rawget(_G, "slua_loader")
        if loader then
            loader.verifyBytecode = retTrue
            loader.checkIntegrity = retTrue
            if loader.disableSignatureCheck then loader.disableSignatureCheck = retTrue end
        end
        local slua_serialize = package.loaded["slua.serialize"]
        if slua_serialize then slua_serialize.check = retTrue; slua_serialize.verify = retTrue end
        if jit and jit.attach then jit.attach(function() end, "bc") end
    end)
end

local function InitializeMD5Bypass()
    pcall(function()
        local CMode = import("CreativeModeBlueprintLibrary")
        if CMode then
            CMode.MD5HashByteArray = function() return "00000000000000000000000000000000" end
            CMode.VerifyFileIntegrity = retTrue
        end
        local FileHashChecker = package.loaded["common.file_hash_checker"]
        if FileHashChecker then
            FileHashChecker.CheckFileMD5 = retTrue; FileHashChecker.VerifyAll = retTrue
        end
        local TssSdk = package.loaded["TssSdk"] or _G.TssSdk
        if TssSdk then TssSdk.GetFileMD5 = function() return "BYPASS" end; TssSdk.VerifyFileSignature = retTrue end
        local STExtra = import("STExtraBlueprintFunctionLibrary")
        if STExtra then STExtra.CheckMD5 = retTrue; STExtra.GetMD5 = function() return "BYPASS" end end
    end)
end

local function InitializeLogBlocker()
    pcall(function()
        local TLog = package.loaded["TLog"] or _G.TLog
        if TLog then TLog.Info = nop; TLog.Warning = nop; TLog.Error = nop; TLog.Debug = nop end
        local CrashSight = package.loaded["CrashSight"] or _G.CrashSight
        if CrashSight then CrashSight.ReportException = nop; CrashSight.SetCustomData = nop end
        local GRUtils = package.loaded["GameLua.Mod.BaseMod.GamePlay.GameReport.GameReportUtils"]
        if GRUtils then GRUtils.BugglyPostExceptionFull = retFalse; GRUtils.ReportGameException = nop end
    end)
end

local function InitializeScannerBlocker()
    pcall(function()
        local SubMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if SubMgr then
            local subs = {"AFKReportorSubsystem", "AvatarExceptionSubsystem", "MemoryCheckSubsystem", "SpeedCheckSubsystem", "WallCheckSubsystem", "FileCheckSubsystem"}
            for _, name in ipairs(subs) do
                local sub = SubMgr:Get(name)
                if sub then
                    for k, v in pairs(sub) do
                        if type(v) == "function" and (k:find("Report") or k:find("Check") or k:find("Scan")) then pcall(function() sub[k] = nop end) end
                    end
                end
            end
        end
        local TssSdk = package.loaded["TssSdk"] or _G.TssSdk
        if TssSdk then
            TssSdk.OnRecvData = nop; TssSdk.SendReportInfo = nop; TssSdk.ScanMemory = retTrue
        end
    end)
end

local function InitializeNetworkPacketBlock()
    pcall(function()
        if NetUtil and NetUtil.SendPacket then
            local orig = NetUtil.SendPacket
            local blocked = {
                ["ReportAttackFlow"]=1, ["ReportSecAttackFlow"]=1, ["ReportFireArms"]=1, ["ReportVerifyInfoFlow"]=1, ["ReportMrpcsFlow"]=1,
                ["ReportPlayerBehavior"]=1, ["ReportTeammatHurt"]=1, ["ReportPlayerMoveRoute"]=1, ["ReportPlayerPosition"]=1,
                ["report_parachute_data"]=1, ["on_tss_sdk_anti_data"]=1, ["ReportAimFlow"]=1, ["ReportHitFlow"]=1, ["ReportCircleFlow"]=1,
                ["report_players_ping"]=1, ["report_player_ip"]=1, ["report_speed_hack"]=1, ["report_wall_hack"]=1, ["report_aim_bot"]=1,
                ["report_esp_usage"]=1, ["detect_cheat"]=1, ["ban_player"]=1, ["client_anti_cheat_report"]=1,
                ["ClientSecMrpcsFlow"]=1, ["MrpcsData"]=1, ["CoronaLabReport"]=1, ["PlayerSecurityInfo"]=1, ["ReportSecurityInfo"]=1,
                ["SwiftHawk"]=1, ["ClientSwiftHawk"]=1, ["AntiCheatReport"]=1, ["CheatDetection"]=1, ["ViolationReport"]=1,
            }
            NetUtil.SendPacket = function(packetName, ...) if blocked[packetName] then return nil end; return orig(packetName, ...) end
        end
    end)
end

local function InitializeHiggsBosonBypass()
    pcall(function()
        local Higgs = require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
        if Higgs then
            for _, m in ipairs({"ControlMHActive", "Tick", "TriggerAvatarCheck", "ReportItemID", "ShowSecurityAlert", "SendHisarData"}) do
                if Higgs[m] then Higgs[m] = nop end
            end
            Higgs.GetNetAvatarItemIDs = retEmpty; Higgs.IsMHActive = retFalse; Higgs.bMHActive = false
        end
        _G.BlackList = {}
        local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
        if slua.isValid(pc) then
            if pc.HiggsBoson then pc.HiggsBoson.bMHActive = false end
            if pc.HiggsBosonComponent then pc.HiggsBosonComponent.bMHActive = false end
        end
    end)
end

local function InitializeGameplayBypass()
    pcall(function()
        if not _G.GameplayCallbacks then _G.GameplayCallbacks = {} end
        local GC = _G.GameplayCallbacks
        local reports = {"ReportAttackFlow", "ReportSecAttackFlow", "ReportFireArms", "ReportVerifyInfoFlow", "ReportMrpcsFlow", "ReportPlayerBehavior", "ReportTeammatHurt", "ReportPlayerMoveRoute", "ReportPlayerPosition", "ReportVehicleMoveFlow", "ReportParachuteData", "ReportEquipmentFlow", "ReportAimFlow", "ReportPlayersPing", "ReportPlayerIP"}
        for _, f in ipairs(reports) do GC[f] = nop end
        GC.CheckReportSecAttackFlowWithAttackFlow = retFalse; GC.CheckReportSecAttackFlow = retFalse
        GC.OnDSPlayerStateChanged = function() end
    end)
end

local function InitializeKillAllSubsystems()
    pcall(function()
        local subMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if not subMgr then return end
        local toKill = {"CoronaLabSubsystem", "PlayerSecurityInfoSubsystem", "ModifierExceptionSubsystem", "ShootVerifySubSystemClient", "ClientReportPlayerSubsystem", "ClientDataStatistcsSubsystem", "AFKReportorSubsystem", "FileCheckSubsystem", "MemoryCheckSubsystem", "SpeedCheckSubsystem", "WallCheckSubsystem", "AvatarExceptionSubsystem", "GameReportSubsystem", "SwiftHawkSubsystem", "AntiCheatSubsystem"}
        for _, name in ipairs(toKill) do
            local sub = subMgr:Get(name)
            if sub then
                for k, v in pairs(sub) do if type(v) == "function" and (k:find("Report") or k:find("Send") or k:find("Upload") or k:find("Verify") or k:find("Check")) then pcall(function() sub[k] = nop end) end end
            end
        end
    end)
end

local function InitializeOperationalStatsBypass()
    pcall(function()
        local subMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        local sub = (subMgr and subMgr:Get("OperationalStatsSubsystem")) or _G.OperationalStatsSubsystem
        if sub then
            sub.ReportOperationalStats = nop; sub.AddOperationalStats = nop; sub.OnInit = nop
        end
    end)
end

_G.StartBypass_VIP_v3 = function()
    pcall(function()
        InitializeSLUABypass()
        InitializeMD5Bypass()
        InitializeLogBlocker()
        InitializeScannerBlocker()
        InitializeNetworkPacketBlock()
        InitializeHiggsBosonBypass()
        InitializeGameplayBypass()
        InitializeKillAllSubsystems()
        InitializeOperationalStatsBypass()
    end)
end

-- ============ AIMBOT HELPER ============
_G.GetEnemyTargetsFromActors = function(radius)
    local result = {}
    local player = GameplayData.GetPlayerCharacter()
    if not (slua and slua.isValid and slua.isValid(player)) then return result end

    local allCharacters = {}
    if GameplayData.GetAllPlayerCharacters then
        allCharacters = GameplayData.GetAllPlayerCharacters()
    elseif GameplayData.GameCharacters then
        for _, char in pairs(GameplayData.GameCharacters) do
            table.insert(allCharacters, char)
        end
    end

    local myTeam = player:GetTeamID()
    for _, actor in pairs(allCharacters) do
        if slua.isValid(actor) and actor ~= player and actor.GetTeamID and actor:IsAlive() then
            if actor:GetTeamID() ~= myTeam then
                local dist = player:GetDistanceTo(actor)
                if dist <= radius then
                    table.insert(result, actor)
                end
            end
        end
    end
    return result
end

-- ============ PLAYER MAP MARKER (ESP ENGINE) ============
local PlayerMapMarker = {}

local RedBoxOverlay = {
    bActive = false, MainContainer = nil, WidgetSlot = nil,
    TextBlockPlayer = nil, TextBlockBot = nil,
    Width = 260, Height = 25, PlayerCount = 0, BotCount = 0,
    FontSize = 14, TextScaleValue = 1.0, NumLayers = 50,
    Red = 0.29, Green = 0.0, Blue = 0.28, LayerAlpha = 0.15,
    _CachedTextPlayer = "", _CachedTextBot = "", _CachedPosVec = nil,
    OffsetY = -8,
}

function RedBoxOverlay.Create()
    if RedBoxOverlay.MainContainer and slua.isValid(RedBoxOverlay.MainContainer) then return true end
    local ParentCanvas = PlayerMapMarker.ESPCanvas
    if not ParentCanvas or not slua.isValid(ParentCanvas) then
        if not PlayerMapMarker.InitESPCanvas() then return false end
        ParentCanvas = PlayerMapMarker.ESPCanvas
    end
    if not ParentCanvas or not slua.isValid(ParentCanvas) then return false end
    local Container = nil
    pcall(function() Container = CGame:NewObjectFromPath("/Script/UMG.CanvasPanel", ParentCanvas) end)
    if not Container or not slua.isValid(Container) then return false end
    local FLinearColor = import("LinearColor") or FLinearColor
    local FVector2D = import("Vector2D") or FVector2D
    local color = FLinearColor(RedBoxOverlay.Red, RedBoxOverlay.Green, RedBoxOverlay.Blue, RedBoxOverlay.LayerAlpha)
    for i = 1, RedBoxOverlay.NumLayers do
        local progress = (i / RedBoxOverlay.NumLayers) ^ 1.15
        local layerWidth = progress * RedBoxOverlay.Width
        local layerX = (RedBoxOverlay.Width - layerWidth) / 2.0
        local border = nil
        pcall(function() border = CGame:NewObjectFromPath("/Script/UMG.Border", Container) end)
        if border and slua.isValid(border) then
            pcall(function() border:SetBrushColor(color) border:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
            local slot = Container:AddChildToCanvas(border)
            if slot then slot:SetPosition(FVector2D(layerX, 0)) slot:SetSize(FVector2D(layerWidth, RedBoxOverlay.Height)) end
        end
    end
    local FSlateColor = import("SlateColor") or import("/Script/SlateCore.SlateColor")
    local txtPlayer = nil
    pcall(function() txtPlayer = CGame:NewObjectFromPath("/Script/UMG.TextBlock", Container) end)
    if txtPlayer and slua.isValid(txtPlayer) then
        pcall(function()
            local strText = string.format("Player: %d", RedBoxOverlay.PlayerCount)
            txtPlayer:SetText(strText)
            RedBoxOverlay._CachedTextPlayer = strText
            local whiteLinear = FLinearColor(1.0, 1.0, 1.0, 1.0)
            if FSlateColor then txtPlayer:SetColorAndOpacity(FSlateColor(whiteLinear)) else txtPlayer:SetColorAndOpacity(whiteLinear) end
            if txtPlayer.Font then local font = txtPlayer.Font; font.Size = RedBoxOverlay.FontSize; txtPlayer.Font = font end
            txtPlayer:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        end)
        local s1 = Container:AddChildToCanvas(txtPlayer)
        if s1 then pcall(function() s1:SetAutoSize(true) s1:SetAlignment(FVector2D(0.5,0.5)) s1:SetPosition(FVector2D(RedBoxOverlay.Width*0.35, RedBoxOverlay.Height*0.5)) s1:SetZOrder(1000) end) end
        RedBoxOverlay.TextBlockPlayer = txtPlayer
    end
    local txtBot = nil
    pcall(function() txtBot = CGame:NewObjectFromPath("/Script/UMG.TextBlock", Container) end)
    if txtBot and slua.isValid(txtBot) then
        pcall(function()
            local strText = string.format("Bot: %d", RedBoxOverlay.BotCount)
            txtBot:SetText(strText)
            RedBoxOverlay._CachedTextBot = strText
            local whiteLinear = FLinearColor(1.0, 1.0, 1.0, 1.0)
            if FSlateColor then txtBot:SetColorAndOpacity(FSlateColor(whiteLinear)) else txtBot:SetColorAndOpacity(whiteLinear) end
            if txtBot.Font then local font = txtBot.Font; font.Size = RedBoxOverlay.FontSize; txtBot.Font = font end
            txtBot:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        end)
        local s2 = Container:AddChildToCanvas(txtBot)
        if s2 then pcall(function() s2:SetAutoSize(true) s2:SetAlignment(FVector2D(0.5,0.5)) s2:SetPosition(FVector2D(RedBoxOverlay.Width*0.65, RedBoxOverlay.Height*0.5)) s2:SetZOrder(1000) end) end
        RedBoxOverlay.TextBlockBot = txtBot
    end
    local MainSlot = nil
    pcall(function() MainSlot = ParentCanvas:AddChildToCanvas(Container) end)
    if not MainSlot then return false end
    RedBoxOverlay.MainContainer = Container
    RedBoxOverlay.WidgetSlot = MainSlot
    pcall(function() MainSlot:SetAutoSize(false) MainSlot:SetZOrder(999) MainSlot:SetAlignment(FVector2D(0.5,0.5)) MainSlot:SetSize(FVector2D(RedBoxOverlay.Width, RedBoxOverlay.Height)) end)
    RedBoxOverlay.UpdatePosition()
    return true
end

function RedBoxOverlay.SetCounts(players, bots)
    if RedBoxOverlay.PlayerCount == players and RedBoxOverlay.BotCount == bots then return end
    RedBoxOverlay.PlayerCount = players or 0
    RedBoxOverlay.BotCount = bots or 0
    if RedBoxOverlay.TextBlockPlayer and slua.isValid(RedBoxOverlay.TextBlockPlayer) then
        pcall(function()
            local strP = string.format("Player: %d", RedBoxOverlay.PlayerCount)
            if RedBoxOverlay._CachedTextPlayer ~= strP then RedBoxOverlay.TextBlockPlayer:SetText(strP) RedBoxOverlay._CachedTextPlayer = strP end
        end)
    end
    if RedBoxOverlay.TextBlockBot and slua.isValid(RedBoxOverlay.TextBlockBot) then
        pcall(function()
            local strB = string.format("Bot: %d", RedBoxOverlay.BotCount)
            if RedBoxOverlay._CachedTextBot ~= strB then RedBoxOverlay.TextBlockBot:SetText(strB) RedBoxOverlay._CachedTextBot = strB end
        end)
    end
end

function RedBoxOverlay.UpdatePosition()
    local Slot = RedBoxOverlay.WidgetSlot
    if not Slot or not slua.isValid(Slot) then return end
    local PC = PlayerMapMarker.GetMyPlayerController()
    if not slua.isValid(PC) then return end
    local fromX, fromY = PlayerMapMarker.GetSnapLineStartPos(PC)
    local FVector2D = import("Vector2D") or FVector2D
    local offsetY = RedBoxOverlay.OffsetY or -8
    pcall(function()
        if not RedBoxOverlay._CachedPosVec then RedBoxOverlay._CachedPosVec = FVector2D(fromX, fromY + offsetY)
        else RedBoxOverlay._CachedPosVec.X = fromX RedBoxOverlay._CachedPosVec.Y = fromY + offsetY end
        Slot:SetPosition(RedBoxOverlay._CachedPosVec)
    end)
end

function RedBoxOverlay.Start()
    if RedBoxOverlay.bActive and RedBoxOverlay.MainContainer and slua.isValid(RedBoxOverlay.MainContainer) then return end
    if RedBoxOverlay.Create() then
        RedBoxOverlay.bActive = true
        pcall(function() RedBoxOverlay.MainContainer:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
    end
end

function RedBoxOverlay.Stop()
    RedBoxOverlay.bActive = false
    if RedBoxOverlay.MainContainer and slua.isValid(RedBoxOverlay.MainContainer) then
        pcall(function() RedBoxOverlay.MainContainer:RemoveFromParent() RedBoxOverlay.MainContainer:ConditionalBeginDestroy() end)
    end
    RedBoxOverlay.MainContainer = nil RedBoxOverlay.WidgetSlot = nil
    RedBoxOverlay.TextBlockPlayer = nil RedBoxOverlay.TextBlockBot = nil
    RedBoxOverlay._CachedPosVec = nil
end

_G.RedBoxOverlay = RedBoxOverlay

local InGameMarkTools = nil
pcall(function() InGameMarkTools = require("GameLua.Mod.BaseMod.Common.InGameMarkTools") end)
local SlateBlueprintLibrary = nil
local WidgetLayoutLibrary = nil
local KismetMathLibrary = nil
local KismetSystemLibrary = nil
pcall(function() SlateBlueprintLibrary = import("SlateBlueprintLibrary") or import("/Script/UMG.SlateBlueprintLibrary") end)
pcall(function() WidgetLayoutLibrary = import("WidgetLayoutLibrary") or import("/Script/UMG.WidgetLayoutLibrary") end)
pcall(function() KismetMathLibrary = import("KismetMathLibrary") end)
pcall(function() KismetSystemLibrary = import("KismetSystemLibrary") end)
local FVector2D = _G.FVector2D or import("Vector2D")
local FLinearColor = _G.FLinearColor or import("LinearColor")
local FVector = _G.FVector or import("Vector")

PlayerMapMarker.MarkTypeID = 1007
PlayerMapMarker.bUseScreenESP = true
PlayerMapMarker.ESPWorldOffsetZ = 0
PlayerMapMarker.ESPAnchorOffsetX = 0
PlayerMapMarker.ESPAnchorOffsetY = 0
PlayerMapMarker.ESPWidgetZOrder = 2
PlayerMapMarker.bShowDistance = true
PlayerMapMarker.WeaponIconBrushW = 96
PlayerMapMarker.WeaponIconBrushH = 48
PlayerMapMarker.bUseSnapLines = true
PlayerMapMarker.SnapLineThickness = 1.5
PlayerMapMarker.SnapLineOriginY = 50
PlayerMapMarker.SnapLineOriginOffsetX = 0
PlayerMapMarker.SnapLineHeadOffsetX = 0
PlayerMapMarker.SnapLineHeadOffsetY = -14
PlayerMapMarker.SnapLineColor = FLinearColor and FLinearColor(1.0, 1.0, 0.0, 0.8) or {R=255, G=255, B=0, A=200}
PlayerMapMarker.SnapLineOpacity = 0.8
PlayerMapMarker.bUseSkeleton = true
PlayerMapMarker.SkeletonThickness = 1.2
PlayerMapMarker.SkeletonOpacity = 0.9
PlayerMapMarker.SkeletonMaxDistance = 100000
PlayerMapMarker.bUseVisibilityColor = false
PlayerMapMarker.SkeletonColor = FLinearColor and FLinearColor(1.0, 1.0, 1.0, 0.9) or {R=255, G=255, B=255, A=230}
PlayerMapMarker.SkeletonWidgets = {}
PlayerMapMarker._StaticBoneLocCache = {}
PlayerMapMarker.SkeletonChains = {
    {"neck_01", "lowerarm_r", "hand_r"}, {"neck_01", "lowerarm_l", "hand_l"},
    {"head", "neck_01", "pelvis"}, {"pelvis", "calf_r", "foot_r"}, {"pelvis", "calf_l", "foot_l"}
}
PlayerMapMarker.BoneNameFallbacks = {
    ["head"] = {"head", "Head", "head_socket"},
    ["neck_01"] = {"neck_01", "Neck_01", "neck", "Neck"},
    ["lowerarm_r"] = {"lowerarm_r", "LowerArm_R", "forearm_r"},
    ["hand_r"] = {"hand_r", "Hand_R", "hand_r_socket"},
    ["lowerarm_l"] = {"lowerarm_l", "LowerArm_L", "forearm_l"},
    ["hand_l"] = {"hand_l", "Hand_L", "hand_l_socket"},
    ["pelvis"] = {"pelvis", "hip"},
    ["calf_r"] = {"calf_r", "Calf_R", "shin_r"},
    ["foot_r"] = {"foot_r", "Foot_R", "foot_r_socket"},
    ["calf_l"] = {"calf_l", "Calf_L", "shin_l"},
    ["foot_l"] = {"foot_l", "Foot_L", "foot_l_socket"},
}

PlayerMapMarker.bUseArrowMarker = true
PlayerMapMarker.ArrowWidgets = {}
PlayerMapMarker.ArrowSize = 18
PlayerMapMarker.ArrowColor = FLinearColor and FLinearColor(1.0, 1.0, 0.0, 1.0) or {R=255, G=255, B=0, A=255}
PlayerMapMarker.ArrowOffsetY = 55

PlayerMapMarker.bUseESPBox = false
PlayerMapMarker.ESPBoxWidgets = {}
PlayerMapMarker.ESPBoxColor = FLinearColor and FLinearColor(1.0, 1.0, 1.0, 0.9) or {R=255, G=255, B=255, A=230}
PlayerMapMarker.ESPBoxThickness = 1.5
PlayerMapMarker.ESPBoxWidth = 60
PlayerMapMarker.ESPBoxHeight = 120

PlayerMapMarker.bUseHPBar = true
PlayerMapMarker.HPBarWidgets = {}
PlayerMapMarker.HPBarWidth = 50
PlayerMapMarker.HPBarHeight = 4
PlayerMapMarker.HPBarOffsetY = 25

PlayerMapMarker.nUpdateInterval = 0.5
PlayerMapMarker.bIncludeMe = false
PlayerMapMarker.bIncludeAI = true
PlayerMapMarker.bActive = false
PlayerMapMarker.ESPCanvas = nil
PlayerMapMarker.ESPWidgets = {}
PlayerMapMarker.ESPWidgetPtrs = {}
PlayerMapMarker.SnapLineWidgets = {}
PlayerMapMarker.DistWidgets = {}
PlayerMapMarker._cachedViewportW = 1920
PlayerMapMarker._cachedViewportH = 1080
PlayerMapMarker._LightUpdateInterval = 0.02

local function IsValid(obj)
    if obj == nil then return false end
    if slua and slua.isValid then return slua.isValid(obj) end
    return obj ~= nil
end

function PlayerMapMarker.GetGameplayData()
    if PlayerMapMarker._CachedGameplayData then return PlayerMapMarker._CachedGameplayData end
    local ok, GDP = pcall(function() return require("GameLua.GameCore.Data.GameplayData") end)
    if ok and GDP then PlayerMapMarker._CachedGameplayData = GDP return GDP end
    return nil
end

function PlayerMapMarker.GetMyPlayerController()
    local PC = PlayerMapMarker._CachedPC
    if PC and IsValid(PC) then return PC end
    local GDP = PlayerMapMarker.GetGameplayData()
    if not GDP then return nil end
    pcall(function() PC = GDP.GetPlayerController and GDP.GetPlayerController() end)
    if PC and IsValid(PC) then PlayerMapMarker._CachedPC = PC return PC end
    return nil
end

function PlayerMapMarker.GetCGameState()
    if CGameState and IsValid(CGameState) then return CGameState end
    if PlayerMapMarker._CachedCGameState and IsValid(PlayerMapMarker._CachedCGameState) then return PlayerMapMarker._CachedCGameState end
    local ok, GS = pcall(function() return require("GameLua.GameCore.Data.CGameState") end)
    if ok and GS then PlayerMapMarker._CachedCGameState = GS return GS end
    return nil
end

function PlayerMapMarker.GetAllCharacters()
    local AllChars = {}
    pcall(function()
        local Pawns = Game:GetAllPlayerPawns()
        if Pawns then
            for _, Pawn in pairs(Pawns) do
                if Pawn and slua.isValid(Pawn) then
                    local pKey = nil
                    if Pawn.GetPlayerKey then pKey = Pawn:GetPlayerKey() end
                    if not pKey and Pawn.PlayerKey then pKey = Pawn.PlayerKey end
                    if pKey then AllChars[pKey] = Pawn end
                end
            end
        end
    end)
    if not next(AllChars) then
        local GS = PlayerMapMarker.GetCGameState()
        if GS and GS.GetAllCharacters then pcall(function() AllChars = GS:GetAllCharacters() end) end
    end
    return AllChars
end

function PlayerMapMarker.GetMyPlayerKey()
    local PC = PlayerMapMarker.GetMyPlayerController()
    if not IsValid(PC) then return nil end
    local MyKey = nil
    pcall(function()
        if PC.GetPlayerKey then MyKey = PC:GetPlayerKey()
        elseif PC.PlayerState and PC.PlayerState.PlayerKey then MyKey = PC.PlayerState.PlayerKey end
    end)
    return MyKey
end

function PlayerMapMarker.IsMe(Character, PlayerKey, MyKey)
    local bIsMe = false
    pcall(function()
        local GDP = PlayerMapMarker.GetGameplayData()
        if GDP and GDP.GetLocalCharacter then
            local MyChar = GDP.GetLocalCharacter()
            if MyChar and Character == MyChar then bIsMe = true return end
        end
        local PC = PlayerMapMarker.GetMyPlayerController()
        if PC and PC.GetPawn then
            local Pawn = PC:GetPawn()
            if Pawn and Character == Pawn then bIsMe = true return end
        end
    end)
    if not bIsMe and MyKey ~= nil and PlayerKey ~= nil then bIsMe = (tostring(PlayerKey) == tostring(MyKey)) end
    return bIsMe
end

function PlayerMapMarker.GetCharacterLocation(Character)
    if not IsValid(Character) then return nil end
    local Loc = nil
    pcall(function() if Character.K2_GetActorLocation then Loc = Character:K2_GetActorLocation() end end)
    if not Loc then pcall(function() if Game and Game.GetActorLocation then Loc = Game:GetActorLocation(Character) end end) end
    return Loc
end

function PlayerMapMarker.CalcDistance(Loc1, Loc2)
    if not Loc1 or not Loc2 then return nil end
    local Dist = nil
    pcall(function() if FVector and FVector.Dist2D then Dist = FVector.Dist2D(Loc1, Loc2) end end)
    if not Dist then
        pcall(function()
            local DX = (Loc1.X or 0) - (Loc2.X or 0)
            local DY = (Loc1.Y or 0) - (Loc2.Y or 0)
            Dist = math.sqrt(DX * DX + DY * DY)
        end)
    end
    return Dist
end

function PlayerMapMarker.GetDistanceString(MyLoc, TargetLoc)
    if not PlayerMapMarker.bShowDistance then return "" end
    if not MyLoc or not TargetLoc then return "" end
    local Dist = PlayerMapMarker.CalcDistance(MyLoc, TargetLoc)
    if not Dist then return "" end
    local Meters = Dist / 100
    if Meters < 1000 then return string.format("%dM", math.floor(Meters))
    else return string.format("%.1fKM", Meters / 1000) end
end

function PlayerMapMarker.GetMyLocation()
    local GDP = PlayerMapMarker.GetGameplayData()
    if not GDP then return nil end
    local MyChar = nil
    pcall(function() MyChar = GDP.GetLocalCharacter and GDP.GetLocalCharacter() end)
    if not IsValid(MyChar) then
        local PC = PlayerMapMarker.GetMyPlayerController()
        if IsValid(PC) then
            pcall(function()
                if PC.GetPawn then
                    local Pawn = PC:GetPawn()
                    if IsValid(Pawn) and Pawn.K2_GetActorLocation then return Pawn:K2_GetActorLocation() end
                end
            end)
        end
        return nil
    end
    return PlayerMapMarker.GetCharacterLocation(MyChar)
end

function PlayerMapMarker.GetPlayerName(Character)
    if not IsValid(Character) then return "ROBOT" end
    local Name = nil
    pcall(function() if Character.GetPlayerNameSafety then Name = Character:GetPlayerNameSafety() end end)
    if not Name then
        pcall(function()
            local PS = nil
            if Character.GetPlayerStateSafety then PS = Character:GetPlayerStateSafety()
            elseif Character.GetPlayerState then PS = Character:GetPlayerState() end
            if IsValid(PS) and PS.GetPlayerName then Name = PS:GetPlayerName() end
        end)
    end
    return Name or "ROBOT"
end

function PlayerMapMarker.IsAI(Character)
    local bAI = false
    pcall(function() if Game and Game.IsAI then bAI = Game:IsAI(Character) end end)
    return bAI
end

function PlayerMapMarker.IsAlive(Character)
    local bAlive = true
    pcall(function() if Character.IsAlive then bAlive = Character:IsAlive() end end)
    return bAlive
end

function PlayerMapMarker.GetTeamID(Character)
    if not IsValid(Character) then return nil end
    local TeamID = nil
    pcall(function() if Character.GetTeamID then TeamID = Character:GetTeamID() end end)
    if not TeamID then
        pcall(function()
            local PS = nil
            if Character.GetPlayerStateSafety then PS = Character:GetPlayerStateSafety()
            elseif Character.GetPlayerState then PS = Character:GetPlayerState() end
            if IsValid(PS) and PS.GetTeamID then TeamID = PS:GetTeamID()
            elseif IsValid(PS) and PS.TeamID then TeamID = PS.TeamID end
        end)
    end
    if not TeamID then pcall(function() if Character.TeamID then TeamID = Character.TeamID end end) end
    return TeamID
end

function PlayerMapMarker.GetTeamColor(TeamID)
    return FLinearColor and FLinearColor(1.0, 1.0, 0.0, 1.0) or {R=255, G=255, B=0, A=255}
end

function PlayerMapMarker.InitESPCanvas()
    if PlayerMapMarker.ESPCanvas and Game:IsValid(PlayerMapMarker.ESPCanvas) then return true end
    local InGameUITools = nil
    pcall(function() InGameUITools = require("GameLua.Mod.BaseMod.Common.UI.InGameUITools") end)
    if not InGameUITools then return false end
    local MainControlBaseUI = nil
    pcall(function() MainControlBaseUI = InGameUITools.GetMainControlBaseUI() end)
    if not MainControlBaseUI or not Game:IsValid(MainControlBaseUI) then return false end
    local ParentCanvas = nil
    pcall(function()
        if MainControlBaseUI.CanvasPanel_0 and Game:IsValid(MainControlBaseUI.CanvasPanel_0) then ParentCanvas = MainControlBaseUI.CanvasPanel_0
        elseif MainControlBaseUI.CanvasPanel_42 and Game:IsValid(MainControlBaseUI.CanvasPanel_42) then ParentCanvas = MainControlBaseUI.CanvasPanel_42 end
    end)
    if not ParentCanvas then return false end
    PlayerMapMarker.ESPCanvas = ParentCanvas
    return true
end

function PlayerMapMarker.GetCharacterWeaponInfo(Character)
    if not IsValid(Character) then return nil end
    local WeaponID, WeaponName, CurrentWeapon = nil, nil, nil
    pcall(function() if Character.GetCurrentWeapon then CurrentWeapon = Character:GetCurrentWeapon() end end)
    if not CurrentWeapon then pcall(function() CurrentWeapon = Character.CurrentWeapon end) end
    if CurrentWeapon and IsValid(CurrentWeapon) then
        pcall(function() if CurrentWeapon.GetWeaponID then WeaponID = CurrentWeapon:GetWeaponID() end end)
        if not WeaponID then pcall(function() WeaponID = CurrentWeapon.WeaponID end) end
        pcall(function() if CurrentWeapon.GetWeaponName then WeaponName = CurrentWeapon:GetWeaponName() end end)
    end
    if not WeaponID then
        pcall(function()
            local PS = nil
            if Character.GetPlayerStateSafety then PS = Character:GetPlayerStateSafety()
            elseif Character.GetPlayerState then PS = Character:GetPlayerState() end
            if PS and IsValid(PS) then
                if PS.GetCurrentWeaponID then WeaponID = PS:GetCurrentWeaponID() end
                if not WeaponID and PS.CurWeaponID then WeaponID = PS.CurWeaponID end
            end
        end)
    end
    return { WeaponID = WeaponID, WeaponName = WeaponName, CurrentWeapon = CurrentWeapon }
end

function PlayerMapMarker.ApplyWeaponIconToImage(ImageWidget, winfo)
    if not ImageWidget or not slua.isValid(ImageWidget) then return false end
    if not winfo or not winfo.WeaponID then return false end
    local iconPath = nil
    pcall(function()
        local itemRecord = CDataTable.GetTableData("Item", winfo.WeaponID)
        if itemRecord and itemRecord.KillWhiteIcon and itemRecord.KillWhiteIcon ~= "" then iconPath = itemRecord.KillWhiteIcon end
        if not iconPath or iconPath == "" then
            local UIUtil = require("client.common.ui_util")
            iconPath = UIUtil.GetItemBigIcon(winfo.WeaponID, ImageWidget)
        end
    end)
    if not iconPath or iconPath == "" then return false end
    local bOK = false
    pcall(function()
        if ImageWidget.SetBrushResourceFromPathSync then ImageWidget:SetBrushResourceFromPathSync(iconPath, true) bOK = true end
    end)
    if bOK then
        pcall(function()
            local brush = ImageWidget.Brush
            if brush then brush.ImageSize = FVector2D and FVector2D(96, 48) or {X=96, Y=48}; brush.DrawAs = 3; ImageWidget:SetBrush(brush) end
        end)
    end
    return bOK
end

PlayerMapMarker._CanvasScaleX = 1.0
PlayerMapMarker._CanvasScaleY = 1.0
PlayerMapMarker._CanvasOffsetX = 0.0
PlayerMapMarker._CanvasOffsetY = 0.0

function PlayerMapMarker.UpdateCanvasTransform(PC)
    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return end
    local success = false
    pcall(function()
        local SBL = SlateBlueprintLibrary
        if SBL and SBL.AbsoluteToLocal then
            local cg = PlayerMapMarker.ESPCanvas:GetCachedGeometry()
            if cg then
                local pt0 = SBL.AbsoluteToLocal(cg, FVector2D and FVector2D(0, 0) or {X=0, Y=0})
                local pt1 = SBL.AbsoluteToLocal(cg, FVector2D and FVector2D(100, 100) or {X=100, Y=100})
                if pt0 and pt1 then
                    PlayerMapMarker._CanvasScaleX = (pt1.X - pt0.X) / 100
                    PlayerMapMarker._CanvasScaleY = (pt1.Y - pt0.Y) / 100
                    PlayerMapMarker._CanvasOffsetX = pt0.X
                    PlayerMapMarker._CanvasOffsetY = pt0.Y
                    success = true
                end
            end
        end
    end)
    if not success then
        local scale = 1.0
        local WLL = WidgetLayoutLibrary
        if WLL and WLL.GetViewportScale then scale = WLL.GetViewportScale(PC) or 1.0 end
        PlayerMapMarker._CanvasScaleX = 1.0 / scale
        PlayerMapMarker._CanvasScaleY = 1.0 / scale
        PlayerMapMarker._CanvasOffsetX = 0
        PlayerMapMarker._CanvasOffsetY = 0
    end
end

function PlayerMapMarker.ScreenPixelToCanvasLocal(PC, ScreenPixelPos)
    if not ScreenPixelPos then return FVector2D and FVector2D(0, 0) or {X=0, Y=0} end
    local scaleX = PlayerMapMarker._CanvasScaleX or 1.0
    local scaleY = PlayerMapMarker._CanvasScaleY or 1.0
    local offsetX = PlayerMapMarker._CanvasOffsetX or 0
    local offsetY = PlayerMapMarker._CanvasOffsetY or 0
    return (FVector2D and FVector2D(ScreenPixelPos.X * scaleX + offsetX, ScreenPixelPos.Y * scaleY + offsetY)) or {X = ScreenPixelPos.X * scaleX + offsetX, Y = ScreenPixelPos.Y * scaleY + offsetY}
end

function PlayerMapMarker.ScreenPixelToCanvasLocalRaw(PC, screenX, screenY)
    local scaleX = PlayerMapMarker._CanvasScaleX or 1.0
    local scaleY = PlayerMapMarker._CanvasScaleY or 1.0
    local offsetX = PlayerMapMarker._CanvasOffsetX or 0
    local offsetY = PlayerMapMarker._CanvasOffsetY or 0
    return screenX * scaleX + offsetX, screenY * scaleY + offsetY
end

function PlayerMapMarker.ProjectWorldToCanvasLocal(PC, WorldLoc)
    if not IsValid(PC) or not WorldLoc then return false, (FVector2D and FVector2D(0, 0) or {X=0, Y=0}) end
    local ScreenPixelPos = FVector2D and FVector2D(0, 0) or {X=0, Y=0}
    local bOK = false
    pcall(function()
        local res = PC:ProjectWorldLocationToScreen(WorldLoc, ScreenPixelPos, true)
        if res == true or res == 1 or (ScreenPixelPos and (ScreenPixelPos.X ~= 0 or ScreenPixelPos.Y ~= 0)) then bOK = true end
    end)
    if not bOK or not ScreenPixelPos or (ScreenPixelPos.X == 0 and ScreenPixelPos.Y == 0) then return false, (FVector2D and FVector2D(0, 0) or {X=0, Y=0}) end
    return true, PlayerMapMarker.ScreenPixelToCanvasLocal(PC, ScreenPixelPos)
end

function PlayerMapMarker.ProjectWorldToCanvasLocalRaw(PC, WorldLoc)
    if not IsValid(PC) or not WorldLoc then return false, 0, 0 end
    if not PlayerMapMarker._tempScreenPixelPos then PlayerMapMarker._tempScreenPixelPos = FVector2D and FVector2D(0, 0) or {X=0, Y=0} end
    local tempPos = PlayerMapMarker._tempScreenPixelPos
    local bOK = false
    pcall(function()
        local res = PC:ProjectWorldLocationToScreen(WorldLoc, tempPos, true)
        if res == true or res == 1 then bOK = true end
    end)
    if not bOK or (tempPos.X == 0 and tempPos.Y == 0) then return false, 0, 0 end
    return true, PlayerMapMarker.ScreenPixelToCanvasLocalRaw(PC, tempPos.X, tempPos.Y)
end

function PlayerMapMarker.GetESPLocation(Character)
    if not IsValid(Character) then return nil end
    local BoneLoc = PlayerMapMarker.GetCharacterLocation(Character)
    if BoneLoc then
        local heightOffset = 85
        pcall(function()
            if Character.bIsCrouched then heightOffset = 60 end
            if Character.IsProne and Character:IsProne() then heightOffset = 30 end
        end)
        pcall(function() BoneLoc.Z = BoneLoc.Z + heightOffset + (PlayerMapMarker.ESPWorldOffsetZ or 0) end)
    end
    return BoneLoc
end

function PlayerMapMarker.GetFootLocation(Character)
    if not IsValid(Character) then return nil end
    local FootLoc = nil
    pcall(function()
        local Mesh = PlayerMapMarker.GetCharacterMesh(Character)
        if Mesh and Game:IsValid(Mesh) then
            local footBone = nil
            if Mesh.GetSocketLocation then
                footBone = Mesh:GetSocketLocation("foot_l")
                if not footBone then footBone = Mesh:GetSocketLocation("foot_r") end
                if not footBone then footBone = Mesh:GetSocketLocation("calf_l") end
            end
            if footBone then FootLoc = footBone end
        end
    end)
    if not FootLoc then
        FootLoc = PlayerMapMarker.GetCharacterLocation(Character)
    end
    return FootLoc
end


function PlayerMapMarker.CreateSnapLine()
    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return nil end
    local Border = nil
    pcall(function() Border = CGame:NewObjectFromPath("/Script/UMG.Border", PlayerMapMarker.ESPCanvas) end)
    if not Border or not slua.isValid(Border) then return nil end
    local color = PlayerMapMarker.SnapLineColor or (FLinearColor and FLinearColor(1.0, 1.0, 0.0, 0.8) or {R=255,G=255,B=0,A=200})
    pcall(function() Border:SetBrushColor(color) Border:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
    pcall(function() Border.RenderTransformPivot = FVector2D and FVector2D(0.0, 0.5) or {X=0,Y=0.5} end)
    local Slot = nil
    pcall(function() Slot = PlayerMapMarker.ESPCanvas:AddChildToCanvas(Border) if Slot then Slot:SetAutoSize(false) Slot:SetZOrder(1) end end)
    return { Widget = Border, Slot = Slot }
end

function PlayerMapMarker.GetSnapLineStartPos(PC)
    local screenPixelW, screenPixelH = 0, 0
    local scale = 1.0
    pcall(function()
        if PC and PC.GetViewportSize then
            local vs = FVector2D and FVector2D(0, 0) or {X=0,Y=0}
            PC:GetViewportSize(vs)
            if vs and vs.X and vs.X > 200 then screenPixelW = vs.X screenPixelH = vs.Y end
        end
    end)
    if screenPixelW <= 200 then
        pcall(function()
            local WLL = WidgetLayoutLibrary
            if WLL and WLL.GetViewportSize then
                local vs = WLL.GetViewportSize(PC)
                if vs and vs.X and vs.X > 200 then screenPixelW = vs.X screenPixelH = vs.Y end
            end
        end)
    end
    pcall(function()
        local WLL = WidgetLayoutLibrary
        if WLL and WLL.GetViewportScale then
            local s = WLL.GetViewportScale(PC)
            if s and type(s) == "number" and s > 0 then scale = s end
        end
    end)
    if screenPixelW <= 200 then
        screenPixelW = (PlayerMapMarker._cachedViewportW or 1920) * scale
        screenPixelH = (PlayerMapMarker._cachedViewportH or 1080) * scale
    end
    if not PlayerMapMarker._CachedTopCenterPixel then PlayerMapMarker._CachedTopCenterPixel = FVector2D and FVector2D(0, 0) or {X=0,Y=0} end
    PlayerMapMarker._CachedTopCenterPixel.X = screenPixelW / 2.0
    PlayerMapMarker._CachedTopCenterPixel.Y = (PlayerMapMarker.SnapLineOriginY or 50) * scale
    local fromCanvasPos = PlayerMapMarker.ScreenPixelToCanvasLocal(PC, PlayerMapMarker._CachedTopCenterPixel)
    return fromCanvasPos.X + (PlayerMapMarker.SnapLineOriginOffsetX or 0), fromCanvasPos.Y
end

function PlayerMapMarker.UpdateSnapLine(KeyStr, CanvasPos, bOnScreen, fromX, fromY)
    if not PlayerMapMarker.bUseSnapLines then return end
    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return end
    local LineData = PlayerMapMarker.SnapLineWidgets[KeyStr]
    if not bOnScreen or not CanvasPos then
        if LineData and LineData.Widget and slua.isValid(LineData.Widget) then
            pcall(function() LineData.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
        end
        return
    end
    local bIsNew = false
    if not LineData then
        LineData = PlayerMapMarker.CreateSnapLine()
        if not LineData or not LineData.Widget or not LineData.Slot then return end
        PlayerMapMarker.SnapLineWidgets[KeyStr] = LineData
        bIsNew = true
    end
    local Widget = LineData.Widget
    local Slot = LineData.Slot
    pcall(function() Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
    local toX = CanvasPos.X + (PlayerMapMarker.SnapLineHeadOffsetX or 0)
    local toY = CanvasPos.Y + (PlayerMapMarker.SnapLineHeadOffsetY or 0)
    local dx = toX - fromX
    local dy = toY - fromY
    local length = math.sqrt(dx * dx + dy * dy)
    local thickness = PlayerMapMarker.SnapLineThickness or 1.5
    local angle_rad = (math.atan2 and math.atan2(dy, dx)) or math.atan(dy, dx)
    local angle = angle_rad * (180.0 / math.pi)
    if not LineData._CachedPosVec then
        LineData._CachedPosVec = FVector2D and FVector2D(fromX, fromY - thickness / 2.0) or {X=fromX, Y=fromY - thickness / 2.0}
        LineData._CachedSizeVec = FVector2D and FVector2D(length, thickness) or {X=length, Y=thickness}
    else
        LineData._CachedPosVec.X = fromX; LineData._CachedPosVec.Y = fromY - thickness / 2.0
        LineData._CachedSizeVec.X = length; LineData._CachedSizeVec.Y = thickness
    end
    pcall(function()
        Slot:SetPosition(LineData._CachedPosVec)
        Slot:SetSize(LineData._CachedSizeVec)
        if bIsNew then Slot:SetZOrder(1) end
    end)
    pcall(function() Widget:SetRenderAngle(angle) end)
end

function PlayerMapMarker.RemoveSnapLine(KeyStr)
    local LineData = PlayerMapMarker.SnapLineWidgets[KeyStr]
    if LineData and LineData.Widget and slua.isValid(LineData.Widget) then
        pcall(function() LineData.Widget:RemoveFromParent() LineData.Widget:ConditionalBeginDestroy() end)
        PlayerMapMarker.SnapLineWidgets[KeyStr] = nil
    end
end

function PlayerMapMarker.ClearAllSnapLines()
    for KeyStr, LineData in pairs(PlayerMapMarker.SnapLineWidgets) do
        if LineData and LineData.Widget and slua.isValid(LineData.Widget) then
            pcall(function() LineData.Widget:RemoveFromParent() LineData.Widget:ConditionalBeginDestroy() end)
        end
    end
    PlayerMapMarker.SnapLineWidgets = {}
end

function PlayerMapMarker.GetCharacterMesh(Character)
    if not IsValid(Character) then return nil end
    local Mesh = nil
    pcall(function() if Character.Mesh and Game:IsValid(Character.Mesh) then Mesh = Character.Mesh end end)
    if not Mesh then pcall(function() local SKC = import("/Script/Engine.SkeletalMeshComponent") Mesh = Character:GetComponentByClass(SKC) end) end
    return Mesh
end

function PlayerMapMarker.GetBoneLocationWithFallback(Character, PrimaryBoneName)
    if not IsValid(Character) or not PrimaryBoneName then return nil end
    if Character._cachedBoneNames and Character._cachedBoneNames[PrimaryBoneName] then
        local cachedName = Character._cachedBoneNames[PrimaryBoneName]
        local loc = nil
        pcall(function()
            local Mesh = PlayerMapMarker.GetCharacterMesh(Character)
            if Mesh and Game:IsValid(Mesh) then
                if Mesh.GetSocketLocation then loc = Mesh:GetSocketLocation(cachedName)
                elseif Mesh.GetBoneLocation then loc = Mesh:GetBoneLocation(cachedName) end
            end
        end)
        if loc then return loc end
    end
    local fallbacks = PlayerMapMarker.BoneNameFallbacks[PrimaryBoneName] or {PrimaryBoneName}
    for _, bname in ipairs(fallbacks) do
        local loc = nil
        pcall(function()
            local Mesh = PlayerMapMarker.GetCharacterMesh(Character)
            if Mesh and Game:IsValid(Mesh) then
                if Mesh.GetSocketLocation then loc = Mesh:GetSocketLocation(bname)
                elseif Mesh.GetBoneLocation then loc = Mesh:GetBoneLocation(bname) end
            end
        end)
        if loc then
            if not Character._cachedBoneNames then Character._cachedBoneNames = {} end
            Character._cachedBoneNames[PrimaryBoneName] = bname
            return loc
        end
    end
    return nil
end

function PlayerMapMarker.CreateSkeletonLineWidget()
    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return nil end
    local Border = nil
    pcall(function() Border = CGame:NewObjectFromPath("/Script/UMG.Border", PlayerMapMarker.ESPCanvas) end)
    if not Border or not slua.isValid(Border) then return nil end
    pcall(function() Border.RenderTransformPivot = FVector2D and FVector2D(0.0, 0.5) or {X=0, Y=0.5} end)
    local Slot = nil
    pcall(function() Slot = PlayerMapMarker.ESPCanvas:AddChildToCanvas(Border) if Slot then Slot:SetAutoSize(false) Slot:SetZOrder(5) end end)
    return { Widget = Border, Slot = Slot, posVec = FVector2D and FVector2D(0, 0) or {X=0, Y=0}, sizeVec = FVector2D and FVector2D(0, 0) or {X=0, Y=0} }
end

function PlayerMapMarker.UpdateSkeletonLines(KeyStr, Character, PC, bVisible, TeamColor, bPlayerOnScreen, charLoc)
    if not PlayerMapMarker.bUseSkeleton then return end
    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return end
    local PlayerBones = PlayerMapMarker.SkeletonWidgets[KeyStr]
    if not bVisible or not IsValid(Character) or not IsValid(PC) then
        if PlayerBones then
            for _, LineData in ipairs(PlayerBones) do
                if LineData and LineData.Widget and slua.isValid(LineData.Widget) then LineData.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end
            end
        end
        return
    end
    if not charLoc then charLoc = PlayerMapMarker.GetESPLocation(Character) end
    if not charLoc then return end
    if bPlayerOnScreen == nil then
        local bOnScreen = PlayerMapMarker.ProjectWorldToCanvasLocalRaw(PC, charLoc)
        bPlayerOnScreen = bOnScreen
    end
    if not bPlayerOnScreen then
        if PlayerBones then
            for _, LineData in ipairs(PlayerBones) do
                if LineData and LineData.Widget and slua.isValid(LineData.Widget) then LineData.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end
            end
        end
        return
    end
    if not PlayerBones then PlayerBones = {} PlayerMapMarker.SkeletonWidgets[KeyStr] = PlayerBones end
    local lineColor = PlayerMapMarker.SkeletonColor or (FLinearColor and FLinearColor(1.0, 1.0, 1.0, 0.9) or {R=255,G=255,B=255,A=230})
    local cache = PlayerMapMarker._StaticBoneLocCache
    for k in pairs(cache) do cache[k] = nil end
    local lineIndex = 0
    local thickness = PlayerMapMarker.SkeletonThickness or 1.2
    for _, chain in ipairs(PlayerMapMarker.SkeletonChains) do
        local lastCanvasX, lastCanvasY = nil, nil
        for _, boneName in ipairs(chain) do
            local boneWorldLoc = cache[boneName]
            if boneWorldLoc == nil then
                boneWorldLoc = PlayerMapMarker.GetBoneLocationWithFallback(Character, boneName) or false
                cache[boneName] = boneWorldLoc
            end
            if boneWorldLoc == false then boneWorldLoc = nil end
            local currentCanvasX, currentCanvasY = nil, nil
            if boneWorldLoc then
                local bOnScreen, cX, cY = PlayerMapMarker.ProjectWorldToCanvasLocalRaw(PC, boneWorldLoc)
                if bOnScreen then currentCanvasX = cX; currentCanvasY = cY end
            end
            if lastCanvasX and currentCanvasX then
                lineIndex = lineIndex + 1
                local LineData = PlayerBones[lineIndex]
                if not LineData or not LineData.Widget or not slua.isValid(LineData.Widget) then
                    LineData = PlayerMapMarker.CreateSkeletonLineWidget()
                    if LineData then PlayerBones[lineIndex] = LineData end
                end
                if LineData and LineData.Widget and LineData.Slot then
                    local Widget = LineData.Widget
                    local Slot = LineData.Slot
                    if Widget._cachedColor ~= lineColor then Widget:SetBrushColor(lineColor) Widget._cachedColor = lineColor end
                    pcall(function() Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
                    local fromX = lastCanvasX
                    local fromY = lastCanvasY
                    local toX = currentCanvasX
                    local toY = currentCanvasY
                    local dx = toX - fromX
                    local dy = toY - fromY
                    local length = math.sqrt(dx * dx + dy * dy)
                    local angle_rad = (math.atan2 and math.atan2(dy, dx)) or math.atan(dy, dx)
                    local angle = angle_rad * 57.29577951308232
                    local pVec = LineData.posVec
                    pVec.X = fromX; pVec.Y = fromY - thickness / 2.0
                    Slot:SetPosition(pVec)
                    local sVec = LineData.sizeVec
                    sVec.X = length; sVec.Y = thickness
                    Slot:SetSize(sVec)
                    Widget:SetRenderAngle(angle)
                end
            end
            lastCanvasX = currentCanvasX
            lastCanvasY = currentCanvasY
        end
    end
    for i = lineIndex + 1, #PlayerBones do
        local LineData = PlayerBones[i]
        if LineData and LineData.Widget and slua.isValid(LineData.Widget) then LineData.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end
    end
end

function PlayerMapMarker.RemoveSkeletonLines(KeyStr)
    local PlayerBones = PlayerMapMarker.SkeletonWidgets[KeyStr]
    if PlayerBones then
        for _, LineData in ipairs(PlayerBones) do
            if LineData and LineData.Widget and slua.isValid(LineData.Widget) then
                pcall(function() LineData.Widget:RemoveFromParent() LineData.Widget:ConditionalBeginDestroy() end)
            end
        end
        PlayerMapMarker.SkeletonWidgets[KeyStr] = nil
    end
end

function PlayerMapMarker.ClearAllSkeletonLines()
    for KeyStr, PlayerBones in pairs(PlayerMapMarker.SkeletonWidgets) do
        for _, LineData in ipairs(PlayerBones) do
            if LineData and LineData.Widget and slua.isValid(LineData.Widget) then
                pcall(function() LineData.Widget:RemoveFromParent() LineData.Widget:ConditionalBeginDestroy() end)
            end
        end
    end
    PlayerMapMarker.SkeletonWidgets = {}
end

function PlayerMapMarker.CreateArrowMarker()
    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return nil end
    local ArrowWidget = nil
    pcall(function() ArrowWidget = CGame:NewObjectFromPath("/Script/UMG.TextBlock", PlayerMapMarker.ESPCanvas) end)
    if not ArrowWidget or not slua.isValid(ArrowWidget) then return nil end
    local FSlateColor = import("SlateColor") or import("/Script/SlateCore.SlateColor")
    pcall(function()
        ArrowWidget:SetText("▼")
        local arrowColor = PlayerMapMarker.ArrowColor or FLinearColor(1.0, 1.0, 0.0, 1.0)
        if FSlateColor then ArrowWidget:SetColorAndOpacity(FSlateColor(arrowColor)) else ArrowWidget:SetColorAndOpacity(arrowColor) end
        if ArrowWidget.Font then local f = ArrowWidget.Font; f.Size = PlayerMapMarker.ArrowSize or 18; ArrowWidget.Font = f end
        ArrowWidget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    end)
    local Slot = nil
    pcall(function() Slot = PlayerMapMarker.ESPCanvas:AddChildToCanvas(ArrowWidget) if Slot then Slot:SetAutoSize(true) Slot:SetZOrder(8) Slot:SetAlignment(FVector2D(0.5, 0.5)) end end)
    return { Widget = ArrowWidget, Slot = Slot, posVec = FVector2D and FVector2D(0, 0) or {X=0, Y=0} }
end

function PlayerMapMarker.UpdateArrowMarker(KeyStr, CanvasPos, bOnScreen)
    if not PlayerMapMarker.bUseArrowMarker then return end
    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return end
    local ArrowData = PlayerMapMarker.ArrowWidgets[KeyStr]
    if not bOnScreen or not CanvasPos then
        if ArrowData and ArrowData.Widget and slua.isValid(ArrowData.Widget) then
            ArrowData.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
        end
        return
    end
    if not ArrowData then
        ArrowData = PlayerMapMarker.CreateArrowMarker()
        if not ArrowData or not ArrowData.Widget then return end
        PlayerMapMarker.ArrowWidgets[KeyStr] = ArrowData
    end
    pcall(function()
        ArrowData.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        ArrowData.posVec.X = CanvasPos.X
        ArrowData.posVec.Y = CanvasPos.Y - 40
        ArrowData.Slot:SetPosition(ArrowData.posVec)
    end)
end

function PlayerMapMarker.RemoveArrowMarker(KeyStr)
    local ArrowData = PlayerMapMarker.ArrowWidgets[KeyStr]
    if ArrowData and ArrowData.Widget and slua.isValid(ArrowData.Widget) then
        pcall(function() ArrowData.Widget:RemoveFromParent() ArrowData.Widget:ConditionalBeginDestroy() end)
        PlayerMapMarker.ArrowWidgets[KeyStr] = nil
    end
end

function PlayerMapMarker.ClearAllArrowMarkers()
    for KeyStr, ArrowData in pairs(PlayerMapMarker.ArrowWidgets) do
        if ArrowData and ArrowData.Widget and slua.isValid(ArrowData.Widget) then
            pcall(function() ArrowData.Widget:RemoveFromParent() ArrowData.Widget:ConditionalBeginDestroy() end)
        end
    end
    PlayerMapMarker.ArrowWidgets = {}
end

function PlayerMapMarker.CreateESPBoxLine()
    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return nil end
    local Border = nil
    pcall(function() Border = CGame:NewObjectFromPath("/Script/UMG.Border", PlayerMapMarker.ESPCanvas) end)
    if not Border or not slua.isValid(Border) then return nil end
    pcall(function()
        Border:SetBrushColor(PlayerMapMarker.ESPBoxColor)
        Border:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        Border.RenderTransformPivot = FVector2D and FVector2D(0.0, 0.5) or {X=0, Y=0.5}
    end)
    local Slot = nil
    pcall(function() Slot = PlayerMapMarker.ESPCanvas:AddChildToCanvas(Border) if Slot then Slot:SetAutoSize(false) Slot:SetZOrder(6) end end)
    return { Widget = Border, Slot = Slot, posVec = FVector2D and FVector2D(0, 0) or {X=0, Y=0}, sizeVec = FVector2D and FVector2D(0, 0) or {X=0, Y=0} }
end

function PlayerMapMarker.UpdateESPBox(KeyStr, CanvasPos, bOnScreen)
    if not PlayerMapMarker.bUseESPBox then return end
    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return end
    local BoxLines = PlayerMapMarker.ESPBoxWidgets[KeyStr]
    if not bOnScreen or not CanvasPos then
        if BoxLines then
            for _, LineData in ipairs(BoxLines) do
                if LineData and LineData.Widget and slua.isValid(LineData.Widget) then LineData.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end
            end
        end
        return
    end
    if not BoxLines then
        BoxLines = {}
        for i = 1, 4 do
            local LineData = PlayerMapMarker.CreateESPBoxLine()
            if LineData then BoxLines[i] = LineData end
        end
        PlayerMapMarker.ESPBoxWidgets[KeyStr] = BoxLines
    end
    local boxW = 40
    local boxH = 80
    local thickness = 1.5
    local centerX = CanvasPos.X
    local topY = CanvasPos.Y - 5
    local bottomY = topY + boxH
    local leftX = centerX - boxW / 2
    local rightX = centerX + boxW / 2
    local lines = {
        { x1 = leftX, y1 = topY, x2 = rightX, y2 = topY },
        { x1 = leftX, y1 = bottomY, x2 = rightX, y2 = bottomY },
        { x1 = leftX, y1 = topY, x2 = leftX, y2 = bottomY },
        { x1 = rightX, y1 = topY, x2 = rightX, y2 = bottomY },
    }
    for i, lineInfo in ipairs(lines) do
        local LineData = BoxLines[i]
        if LineData and LineData.Widget and LineData.Slot then
            pcall(function() LineData.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
            local fromX, fromY = lineInfo.x1, lineInfo.y1
            local toX, toY = lineInfo.x2, lineInfo.y2
            local dx = toX - fromX
            local dy = toY - fromY
            local length = math.sqrt(dx * dx + dy * dy)
            local angle_rad = (math.atan2 and math.atan2(dy, dx)) or math.atan(dy, dx)
            local angle = angle_rad * 57.29577951308232
            LineData.posVec.X = fromX
            LineData.posVec.Y = fromY - thickness / 2.0
            LineData.Slot:SetPosition(LineData.posVec)
            LineData.sizeVec.X = length
            LineData.sizeVec.Y = thickness
            LineData.Slot:SetSize(LineData.sizeVec)
            LineData.Widget:SetRenderAngle(angle)
        end
    end
end

function PlayerMapMarker.RemoveESPBox(KeyStr)
    local BoxLines = PlayerMapMarker.ESPBoxWidgets[KeyStr]
    if BoxLines then
        for _, LineData in ipairs(BoxLines) do
            if LineData and LineData.Widget and slua.isValid(LineData.Widget) then
                pcall(function() LineData.Widget:RemoveFromParent() LineData.Widget:ConditionalBeginDestroy() end)
            end
        end
        PlayerMapMarker.ESPBoxWidgets[KeyStr] = nil
    end
end

function PlayerMapMarker.ClearAllESPBoxes()
    for KeyStr, BoxLines in pairs(PlayerMapMarker.ESPBoxWidgets) do
        for _, LineData in ipairs(BoxLines) do
            if LineData and LineData.Widget and slua.isValid(LineData.Widget) then
                pcall(function() LineData.Widget:RemoveFromParent() LineData.Widget:ConditionalBeginDestroy() end)
            end
        end
    end
    PlayerMapMarker.ESPBoxWidgets = {}
end

function PlayerMapMarker.CreateHPBarWidget()
    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return nil end
    local BGWidget = nil
    pcall(function() BGWidget = CGame:NewObjectFromPath("/Script/UMG.Border", PlayerMapMarker.ESPCanvas) end)
    if not BGWidget or not slua.isValid(BGWidget) then return nil end
    pcall(function()
        BGWidget:SetBrushColor(FLinearColor and FLinearColor(0.1, 0.1, 0.1, 0.8) or {R=25,G=25,B=25,A=200})
        BGWidget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        BGWidget.RenderTransformPivot = FVector2D and FVector2D(0.0, 0.5) or {X=0, Y=0.5}
    end)
    local BGSlot = nil
    pcall(function() BGSlot = PlayerMapMarker.ESPCanvas:AddChildToCanvas(BGWidget) if BGSlot then BGSlot:SetAutoSize(false) BGSlot:SetZOrder(7) end end)
    local FillWidget = nil
    pcall(function() FillWidget = CGame:NewObjectFromPath("/Script/UMG.Border", PlayerMapMarker.ESPCanvas) end)
    if not FillWidget or not slua.isValid(FillWidget) then return nil end
    pcall(function()
        FillWidget:SetBrushColor(FLinearColor and FLinearColor(0.0, 1.0, 0.0, 1.0) or {R=0,G=255,B=0,A=255})
        FillWidget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        FillWidget.RenderTransformPivot = FVector2D and FVector2D(0.0, 0.5) or {X=0, Y=0.5}
    end)
    local FillSlot = nil
    pcall(function() FillSlot = PlayerMapMarker.ESPCanvas:AddChildToCanvas(FillWidget) if FillSlot then FillSlot:SetAutoSize(false) FillSlot:SetZOrder(8) end end)
    return { BGWidget = BGWidget, BGSlot = BGSlot, FillWidget = FillWidget, FillSlot = FillSlot,
             bgPos = FVector2D and FVector2D(0, 0) or {X=0, Y=0},
             bgSize = FVector2D and FVector2D(0, 0) or {X=0, Y=0},
             fillPos = FVector2D and FVector2D(0, 0) or {X=0, Y=0},
             fillSize = FVector2D and FVector2D(0, 0) or {X=0, Y=0} }
end

function PlayerMapMarker.UpdateHPBar(KeyStr, CanvasPos, bOnScreen, HPPercent)
    if not PlayerMapMarker.bUseHPBar then return end
    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return end
    local HPData = PlayerMapMarker.HPBarWidgets[KeyStr]
    if not bOnScreen or not CanvasPos then
        if HPData then
            if HPData.BGWidget and slua.isValid(HPData.BGWidget) then HPData.BGWidget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end
            if HPData.FillWidget and slua.isValid(HPData.FillWidget) then HPData.FillWidget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end
        end
        return
    end
    if not HPData then
        HPData = PlayerMapMarker.CreateHPBarWidget()
        if not HPData then return end
        PlayerMapMarker.HPBarWidgets[KeyStr] = HPData
    end
    local barW = 40
    local barH = 3
    local offsetY = 22
    if HPPercent == nil then HPPercent = 1.0 end
    if HPPercent < 0 then HPPercent = 0 end
    if HPPercent > 1 then HPPercent = 1 end
    local fillW = barW * HPPercent
    local barX = CanvasPos.X - barW / 2
    local barY = CanvasPos.Y - offsetY
    local color
    if HPPercent > 0.5 then
        color = FLinearColor and FLinearColor(0.0, 1.0, 0.0, 1.0) or {R=0,G=255,B=0,A=255}
    elseif HPPercent > 0.25 then
        color = FLinearColor and FLinearColor(1.0, 0.5, 0.0, 1.0) or {R=255,G=128,B=0,A=255}
    else
        color = FLinearColor and FLinearColor(1.0, 0.0, 0.0, 1.0) or {R=255,G=0,B=0,A=255}
    end
    pcall(function()
        HPData.BGWidget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        HPData.bgPos.X = barX; HPData.bgPos.Y = barY
        HPData.bgSize.X = barW; HPData.bgSize.Y = barH
        HPData.BGSlot:SetPosition(HPData.bgPos)
        HPData.BGSlot:SetSize(HPData.bgSize)
        HPData.FillWidget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        HPData.FillWidget:SetBrushColor(color)
        HPData.fillPos.X = barX; HPData.fillPos.Y = barY
        HPData.fillSize.X = fillW; HPData.fillSize.Y = barH
        HPData.FillSlot:SetPosition(HPData.fillPos)
        HPData.FillSlot:SetSize(HPData.fillSize)
    end)
end

function PlayerMapMarker.RemoveHPBar(KeyStr)
    local HPData = PlayerMapMarker.HPBarWidgets[KeyStr]
    if HPData then
        if HPData.BGWidget and slua.isValid(HPData.BGWidget) then
            pcall(function() HPData.BGWidget:RemoveFromParent() HPData.BGWidget:ConditionalBeginDestroy() end)
        end
        if HPData.FillWidget and slua.isValid(HPData.FillWidget) then
            pcall(function() HPData.FillWidget:RemoveFromParent() HPData.FillWidget:ConditionalBeginDestroy() end)
        end
        PlayerMapMarker.HPBarWidgets[KeyStr] = nil
    end
end

function PlayerMapMarker.ClearAllHPBars()
    for KeyStr, HPData in pairs(PlayerMapMarker.HPBarWidgets) do
        if HPData then
            if HPData.BGWidget and slua.isValid(HPData.BGWidget) then
                pcall(function() HPData.BGWidget:RemoveFromParent() HPData.BGWidget:ConditionalBeginDestroy() end)
            end
            if HPData.FillWidget and slua.isValid(HPData.FillWidget) then
                pcall(function() HPData.FillWidget:RemoveFromParent() HPData.FillWidget:ConditionalBeginDestroy() end)
            end
        end
    end
    PlayerMapMarker.HPBarWidgets = {}
end

function PlayerMapMarker.CreateDistWidget()
    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return nil end
    local DistText = nil
    pcall(function() DistText = CGame:NewObjectFromPath("/Script/UMG.TextBlock", PlayerMapMarker.ESPCanvas) end)
    if not DistText or not slua.isValid(DistText) then return nil end
    local FSlateColor = import("SlateColor") or import("/Script/SlateCore.SlateColor")
    pcall(function()
        DistText:SetText("")
        local whiteColor = FLinearColor(1.0, 1.0, 1.0, 1.0)
        if FSlateColor then DistText:SetColorAndOpacity(FSlateColor(whiteColor)) else DistText:SetColorAndOpacity(whiteColor) end
        if DistText.Font then local f = DistText.Font; f.Size = 12; DistText.Font = f end
        DistText:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    end)
    local slot = nil
    pcall(function() slot = PlayerMapMarker.ESPCanvas:AddChildToCanvas(DistText) end)
    if not slot then return nil end
    pcall(function() slot:SetAutoSize(true) slot:SetZOrder(50) slot:SetAlignment(FVector2D(0.5, 0.0)) end)
    return { Widget = DistText, Slot = slot, posVec = FVector2D and FVector2D(0, 0) or {X=0, Y=0}, _LastText = "" }
end

function PlayerMapMarker.UpdateDistWidget(KeyStr, FootCanvasPos, bOnScreen, DistStr)
    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return end
    local DistData = PlayerMapMarker.DistWidgets[KeyStr]
    if not bOnScreen or not FootCanvasPos then
        if DistData and DistData.Widget and slua.isValid(DistData.Widget) then
            DistData.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
        end
        return
    end
    if not DistData then
        DistData = PlayerMapMarker.CreateDistWidget()
        if not DistData then return end
        PlayerMapMarker.DistWidgets[KeyStr] = DistData
    end
    if DistData._LastText ~= DistStr then
        DistData._LastText = DistStr
        pcall(function() DistData.Widget:SetText(DistStr) end)
    end
    pcall(function()
        DistData.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        DistData.posVec.X = FootCanvasPos.X
        DistData.posVec.Y = FootCanvasPos.Y + 10
        DistData.Slot:SetPosition(DistData.posVec)
    end)
end

function PlayerMapMarker.RemoveDistWidget(KeyStr)
    local DistData = PlayerMapMarker.DistWidgets[KeyStr]
    if DistData and DistData.Widget and slua.isValid(DistData.Widget) then
        pcall(function() DistData.Widget:RemoveFromParent() DistData.Widget:ConditionalBeginDestroy() end)
        PlayerMapMarker.DistWidgets[KeyStr] = nil
    end
end

function PlayerMapMarker.ClearAllDistWidgets()
    for KeyStr, DistData in pairs(PlayerMapMarker.DistWidgets) do
        if DistData and DistData.Widget and slua.isValid(DistData.Widget) then
            pcall(function() DistData.Widget:RemoveFromParent() DistData.Widget:ConditionalBeginDestroy() end)
        end
    end
    PlayerMapMarker.DistWidgets = {}
end

function PlayerMapMarker.CreateESPWidget()
    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return nil end
    local Container = nil
    pcall(function() Container = CGame:NewObjectFromPath("/Script/UMG.CanvasPanel", PlayerMapMarker.ESPCanvas) end)
    if not Container or not slua.isValid(Container) then return nil end
    local FSlateColor = import("SlateColor") or import("/Script/SlateCore.SlateColor")
    local FVector2D = import("Vector2D") or FVector2D

    local NameText = nil
    pcall(function() NameText = CGame:NewObjectFromPath("/Script/UMG.TextBlock", Container) end)
    if NameText and slua.isValid(NameText) then
        pcall(function()
            NameText:SetText("")
            local whiteColor = FLinearColor(1.0, 1.0, 1.0, 1.0)
            if FSlateColor then NameText:SetColorAndOpacity(FSlateColor(whiteColor)) else NameText:SetColorAndOpacity(whiteColor) end
            if NameText.Font then local f = NameText.Font; f.Size = 12; NameText.Font = f end
            NameText:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        end)
        local nslot = Container:AddChildToCanvas(NameText)
        if nslot then pcall(function() nslot:SetAutoSize(true) nslot:SetAlignment(FVector2D(0.5, 1.0)) nslot:SetPosition(FVector2D(0, 0)) nslot:SetZOrder(100) end) end
    end

  local WeaponImg = nil
-- pcall(function() WeaponImg = CGame:NewObjectFromPath("/Script/UMG.Image", Container) end)
-- if WeaponImg and slua.isValid(WeaponImg) then
--     pcall(function() WeaponImg:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
--     local wslot = Container:AddChildToCanvas(WeaponImg)
--     if wslot then pcall(function() wslot:SetAutoSize(false) wslot:SetAlignment(FVector2D(0.5, 0.0)) wslot:SetPosition(FVector2D(-48, 0)) wslot:SetSize(FVector2D(96, 48)) wslot:SetZOrder(99) end) end
-- end

    local MainSlot = nil
    pcall(function() MainSlot = PlayerMapMarker.ESPCanvas:AddChildToCanvas(Container) end)
    if not MainSlot then return nil end
    pcall(function() MainSlot:SetAutoSize(true) MainSlot:SetZOrder(PlayerMapMarker.ESPWidgetZOrder or 20) MainSlot:SetAlignment(FVector2D(0.5, 1.0)) end)
    return { Container = Container, NameText = NameText, WeaponImg = WeaponImg, Slot = MainSlot }
end

function PlayerMapMarker.UpdateESPText(Widget, NameText)
    if not Widget then return end
    if Widget._LastName == NameText then return end
    Widget._LastName = NameText
    if Widget.NameText and slua.isValid(Widget.NameText) then
        pcall(function()
            if Widget.NameText.Font then
                local f = Widget.NameText.Font
                f.Size = 12
                Widget.NameText.Font = f
            end
        end)
        pcall(function() Widget.NameText:SetText(NameText) end)
    end
end

function PlayerMapMarker.UpdateESPWeapon(Widget, Character)
    if not Widget or not Widget.WeaponImg then return end
    if not slua.isValid(Widget.WeaponImg) then return end
    local winfo = PlayerMapMarker.GetCharacterWeaponInfo(Character)
    if not winfo or not winfo.WeaponID or winfo.WeaponID == 0 then
        pcall(function() Widget.WeaponImg:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
        return
    end
    if Widget._LastWeaponID == winfo.WeaponID then
        pcall(function() Widget.WeaponImg:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
        return
    end
    if PlayerMapMarker.ApplyWeaponIconToImage(Widget.WeaponImg, winfo) then
        pcall(function() Widget.WeaponImg:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
        Widget._LastWeaponID = winfo.WeaponID
    else
        pcall(function() Widget.WeaponImg:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
    end
end

function PlayerMapMarker.UpdateESPPositionWithPC(Widget, WorldLoc, PC, CanvasPos)
    if not Widget or not IsValid(PC) then return false end
    local Container = Widget.Container or Widget
    local bOnScreen = true
    if not CanvasPos then
        if not WorldLoc then return false end
        bOnScreen, CanvasPos = PlayerMapMarker.ProjectWorldToCanvasLocal(PC, WorldLoc)
    end
    if not bOnScreen then
        pcall(function() Container:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
        return false
    end
    pcall(function()
        Container:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        local Slot = Widget.Slot
        if Slot and slua.isValid(Slot) then
            local finalX = CanvasPos.X
            local finalY = CanvasPos.Y - 30
            Slot:SetPosition(FVector2D and FVector2D(finalX, finalY) or {X=finalX, Y=finalY})
        end
    end)
    return true
end

function PlayerMapMarker.RemoveESPWidget(Widget, KeyStr)
    if not Widget then return end
    local Container = Widget.Container or Widget
    pcall(function()
        Container:RemoveFromParent()
        Container:ConditionalBeginDestroy()
    end)
    if KeyStr then
        PlayerMapMarker.RemoveSnapLine(KeyStr)
        PlayerMapMarker.RemoveSkeletonLines(KeyStr)
        PlayerMapMarker.RemoveArrowMarker(KeyStr)
        PlayerMapMarker.RemoveESPBox(KeyStr)
        PlayerMapMarker.RemoveHPBar(KeyStr)
        PlayerMapMarker.RemoveDistWidget(KeyStr)
    end
end

function PlayerMapMarker.ClearAllESP()
    RedBoxOverlay.Stop()
    if _G.CreditText then pcall(function() _G.CreditText.Stop() end) end
    for KeyStr, Data in pairs(PlayerMapMarker.ESPWidgets) do PlayerMapMarker.RemoveESPWidget(Data.Widget, KeyStr) end
    PlayerMapMarker.ESPWidgets = {}
    PlayerMapMarker.ESPWidgetPtrs = {}
    PlayerMapMarker.ClearAllSnapLines()
    PlayerMapMarker.ClearAllSkeletonLines()
    PlayerMapMarker.ClearAllArrowMarkers()
    PlayerMapMarker.ClearAllESPBoxes()
    PlayerMapMarker.ClearAllHPBars()
    PlayerMapMarker.ClearAllDistWidgets()
    PlayerMapMarker.ESPCanvas = nil
end

function PlayerMapMarker.UpdateESP(AllPlayers, MyLoc)
    if not PlayerMapMarker.bUseScreenESP then return end
    if not PlayerMapMarker.InitESPCanvas() then return end
    local PC = PlayerMapMarker.GetMyPlayerController()
    if IsValid(PC) then PlayerMapMarker.UpdateCanvasTransform(PC) end
    local fromX, fromY = 0, 0
    if PlayerMapMarker.bUseSnapLines and IsValid(PC) then fromX, fromY = PlayerMapMarker.GetSnapLineStartPos(PC) end
    local MyKey = PlayerMapMarker.GetMyPlayerKey()
    local SeenKeys = {}
    local MyChar = nil
    pcall(function()
        local GDP = PlayerMapMarker.GetGameplayData()
        if GDP and GDP.GetLocalCharacter then MyChar = GDP.GetLocalCharacter()
        else if PC and PC.GetPawn then MyChar = PC:GetPawn() end end
    end)
    local MyTeamID = PlayerMapMarker.GetTeamID(MyChar)
    for PlayerKey, Character in pairs(AllPlayers) do
        if IsValid(Character) then
            local bIsMe = PlayerMapMarker.IsMe(Character, PlayerKey, MyKey)
            local bIsAI = PlayerMapMarker.IsAI(Character)
            local KeyStr = tostring(PlayerKey)
            local Name = PlayerMapMarker.GetPlayerName(Character)
            local Loc = PlayerMapMarker.GetESPLocation(Character)
            local FootLoc = PlayerMapMarker.GetFootLocation(Character)
            local DistStr = ""
            if MyLoc and Loc then DistStr = PlayerMapMarker.GetDistanceString(MyLoc, Loc) end
            local bSkip = false
            if bIsMe and not PlayerMapMarker.bIncludeMe then bSkip = true end
            if bIsAI and not PlayerMapMarker.bIncludeAI then bSkip = true end
            local TeamID = PlayerMapMarker.GetTeamID(Character)
            if MyTeamID ~= nil and TeamID == MyTeamID and not bIsMe then bSkip = true end
            local bIsAlive = PlayerMapMarker.IsAlive(Character)
            if not bSkip and Loc then
                SeenKeys[KeyStr] = true
                local ESPData = PlayerMapMarker.ESPWidgets[KeyStr]
                local NameStr = "(" .. (bIsAI and "ROBOT" or "PLAYER") .. ")"
                local DistOnly = DistStr ~= "" and DistStr or "0M"
                local bOnScreen, CanvasPos = PlayerMapMarker.ProjectWorldToCanvasLocal(PC, Loc)
                local bFootOnScreen, FootCanvasPos = PlayerMapMarker.ProjectWorldToCanvasLocal(PC, FootLoc or Loc)
                if not ESPData then
                    local Widget = PlayerMapMarker.CreateESPWidget()
                    if Widget then
                        PlayerMapMarker.ESPWidgets[KeyStr] = { Widget = Widget, Character = Character, Name = Name, TeamID = TeamID, LastName = NameStr }
                        PlayerMapMarker.UpdateESPText(Widget, NameStr)
                        PlayerMapMarker.UpdateESPWeapon(Widget, Character)
                        if bIsAlive then
                            PlayerMapMarker.UpdateESPPositionWithPC(Widget, Loc, PC, CanvasPos)
                            PlayerMapMarker.UpdateDistWidget(KeyStr, FootCanvasPos, bFootOnScreen, DistOnly)
                            local HP = Character.Health or 0
                            local MaxHP = Character.HealthMax or 120
                            local pct = 0
                            if HP > 0 and MaxHP > 0 then pct = HP / MaxHP if pct > 1 then pct = 1 end if pct < 0 then pct = 0 end end
                            if PlayerMapMarker.bUseHPBar then PlayerMapMarker.UpdateHPBar(KeyStr, CanvasPos, bOnScreen, pct) end
                            if PlayerMapMarker.bUseESPBox then PlayerMapMarker.UpdateESPBox(KeyStr, CanvasPos, bOnScreen) end
                            if PlayerMapMarker.bUseArrowMarker then PlayerMapMarker.UpdateArrowMarker(KeyStr, CanvasPos, bOnScreen) end
                            if PlayerMapMarker.bUseSnapLines then PlayerMapMarker.UpdateSnapLine(KeyStr, CanvasPos, bOnScreen, fromX, fromY) end
                            if PlayerMapMarker.bUseSkeleton then PlayerMapMarker.UpdateSkeletonLines(KeyStr, Character, PC, true, nil, bOnScreen, Loc) end
                        else
                            PlayerMapMarker.RemoveSnapLine(KeyStr)
                            PlayerMapMarker.RemoveSkeletonLines(KeyStr)
                            PlayerMapMarker.RemoveArrowMarker(KeyStr)
                            PlayerMapMarker.RemoveESPBox(KeyStr)
                            PlayerMapMarker.RemoveHPBar(KeyStr)
                            PlayerMapMarker.RemoveDistWidget(KeyStr)
                            local Container = Widget.Container or Widget
                            pcall(function() Container:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
                        end
                    end
                else
                    ESPData.Character = Character
                    ESPData.Name = Name
                    if bIsAlive then
                        ESPData.TeamID = TeamID
                        ESPData.Widget._LastName = nil
                        PlayerMapMarker.UpdateESPText(ESPData.Widget, NameStr)
                        PlayerMapMarker.UpdateESPWeapon(ESPData.Widget, Character)
                        PlayerMapMarker.UpdateESPPositionWithPC(ESPData.Widget, Loc, PC, CanvasPos)
                        PlayerMapMarker.UpdateDistWidget(KeyStr, FootCanvasPos, bFootOnScreen, DistOnly)
                        local HP = Character.Health or 0
                        local MaxHP = Character.HealthMax or 120
                        local pct = 0
                        if HP > 0 and MaxHP > 0 then pct = HP / MaxHP if pct > 1 then pct = 1 end if pct < 0 then pct = 0 end end
                        if PlayerMapMarker.bUseHPBar then PlayerMapMarker.UpdateHPBar(KeyStr, CanvasPos, bOnScreen, pct) end
                        if PlayerMapMarker.bUseESPBox then PlayerMapMarker.UpdateESPBox(KeyStr, CanvasPos, bOnScreen) end
                        if PlayerMapMarker.bUseArrowMarker then PlayerMapMarker.UpdateArrowMarker(KeyStr, CanvasPos, bOnScreen) end
                        if PlayerMapMarker.bUseSnapLines then PlayerMapMarker.UpdateSnapLine(KeyStr, CanvasPos, bOnScreen, fromX, fromY) end
                        if PlayerMapMarker.bUseSkeleton then PlayerMapMarker.UpdateSkeletonLines(KeyStr, Character, PC, true, nil, bOnScreen, Loc) end
                    else
                        PlayerMapMarker.RemoveSnapLine(KeyStr)
                        PlayerMapMarker.RemoveSkeletonLines(KeyStr)
                        PlayerMapMarker.RemoveArrowMarker(KeyStr)
                        PlayerMapMarker.RemoveESPBox(KeyStr)
                        PlayerMapMarker.RemoveHPBar(KeyStr)
                        PlayerMapMarker.RemoveDistWidget(KeyStr)
                        local Container = ESPData.Widget.Container or ESPData.Widget
                        pcall(function() Container:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
                    end
                end
            end
        end
    end
    for KeyStr, Data in pairs(PlayerMapMarker.ESPWidgets) do
        if not SeenKeys[KeyStr] then
            PlayerMapMarker.RemoveESPWidget(Data.Widget, KeyStr)
            PlayerMapMarker.RemoveDistWidget(KeyStr)
            PlayerMapMarker.ESPWidgets[KeyStr] = nil
        end
    end
end

function PlayerMapMarker.UpdateESPLight()
    if _G.CreditText and _G.CreditText.bActive then pcall(function() _G.CreditText.UpdatePosition() end) end
    if RedBoxOverlay and RedBoxOverlay.bActive then RedBoxOverlay.UpdatePosition() end
    if not PlayerMapMarker.bUseScreenESP then return end
    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return end
    local PC = PlayerMapMarker.GetMyPlayerController()
    if not IsValid(PC) then return end
    PlayerMapMarker.UpdateCanvasTransform(PC)
    local fromX, fromY = 0, 0
    if PlayerMapMarker.bUseSnapLines then fromX, fromY = PlayerMapMarker.GetSnapLineStartPos(PC) end
    for KeyStr, ESPData in pairs(PlayerMapMarker.ESPWidgets) do
        local Widget = ESPData.Widget
        local Character = ESPData.Character
        local Container = Widget and (Widget.Container or Widget)
        local bWidgetValid = false
        pcall(function() bWidgetValid = Container and slua.isValid(Container) end)
        if Widget and bWidgetValid and Character and IsValid(Character) then
            local bIsAlive = PlayerMapMarker.IsAlive(Character)
            if not bIsAlive then
                pcall(function() Container:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
                PlayerMapMarker.RemoveSnapLine(KeyStr)
                PlayerMapMarker.RemoveSkeletonLines(KeyStr)
                PlayerMapMarker.RemoveArrowMarker(KeyStr)
                PlayerMapMarker.RemoveESPBox(KeyStr)
                PlayerMapMarker.RemoveHPBar(KeyStr)
                PlayerMapMarker.RemoveDistWidget(KeyStr)
            else
                pcall(function() Container:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
                local Loc = PlayerMapMarker.GetESPLocation(Character)
                local FootLoc = PlayerMapMarker.GetFootLocation(Character)
                if Loc then
                    local bOnScreen, CanvasPos = PlayerMapMarker.ProjectWorldToCanvasLocal(PC, Loc)
                    local bFootOnScreen, FootCanvasPos = PlayerMapMarker.ProjectWorldToCanvasLocal(PC, FootLoc or Loc)
                    PlayerMapMarker.UpdateESPPositionWithPC(Widget, Loc, PC, CanvasPos)
                    local MyLocL = PlayerMapMarker.GetMyLocation()
                    local DistStrL = ""
                    if MyLocL then DistStrL = PlayerMapMarker.GetDistanceString(MyLocL, Loc) end
                    PlayerMapMarker.UpdateDistWidget(KeyStr, FootCanvasPos, bFootOnScreen, DistStrL ~= "" and DistStrL or "0M")
                    local HP = Character.Health or 0
                    local MaxHP = Character.HealthMax or 120
                    local pct = 0
                    if HP > 0 and MaxHP > 0 then pct = HP / MaxHP if pct > 1 then pct = 1 end if pct < 0 then pct = 0 end end
                    if PlayerMapMarker.bUseHPBar then PlayerMapMarker.UpdateHPBar(KeyStr, CanvasPos, bOnScreen, pct) end
                    if PlayerMapMarker.bUseESPBox then PlayerMapMarker.UpdateESPBox(KeyStr, CanvasPos, bOnScreen) end
                    if PlayerMapMarker.bUseArrowMarker then PlayerMapMarker.UpdateArrowMarker(KeyStr, CanvasPos, bOnScreen) end
                    if PlayerMapMarker.bUseSnapLines then PlayerMapMarker.UpdateSnapLine(KeyStr, CanvasPos, bOnScreen, fromX, fromY) end
                    if PlayerMapMarker.bUseSkeleton then PlayerMapMarker.UpdateSkeletonLines(KeyStr, Character, PC, true, nil, bOnScreen, Loc) end
                else
                    PlayerMapMarker.RemoveSnapLine(KeyStr)
                    PlayerMapMarker.RemoveSkeletonLines(KeyStr)
                    PlayerMapMarker.RemoveArrowMarker(KeyStr)
                    PlayerMapMarker.RemoveESPBox(KeyStr)
                    PlayerMapMarker.RemoveHPBar(KeyStr)
                    PlayerMapMarker.RemoveDistWidget(KeyStr)
                end
            end
        end
    end
end

function PlayerMapMarker.ScanAndUpdate()
    local AllChars = PlayerMapMarker.GetAllCharacters()
    if not AllChars then RedBoxOverlay.SetCounts(0, 0) return 0 end
    local MyKey = PlayerMapMarker.GetMyPlayerKey()
    local MyLoc = PlayerMapMarker.GetMyLocation()
    local MyChar = nil
    pcall(function()
        local GDP = PlayerMapMarker.GetGameplayData()
        if GDP and GDP.GetLocalCharacter then MyChar = GDP.GetLocalCharacter()
        else local PC = PlayerMapMarker.GetMyPlayerController() if PC and PC.GetPawn then MyChar = PC:GetPawn() end end
    end)
    local MyTeamID = PlayerMapMarker.GetTeamID(MyChar)
    local realPlayers = 0
    local botPlayers = 0
    for PlayerKey, Character in pairs(AllChars) do
        if IsValid(Character) then
            local bIsMe = PlayerMapMarker.IsMe(Character, PlayerKey, MyKey)
            local bIsAI = PlayerMapMarker.IsAI(Character)
            local bIsAlive = PlayerMapMarker.IsAlive(Character)
            if bIsAlive and not bIsMe then
                local bIsMyTeam = false
                if MyTeamID ~= nil then
                    local targetTeamID = PlayerMapMarker.GetTeamID(Character)
                    if targetTeamID == MyTeamID then bIsMyTeam = true end
                end
                if not bIsMyTeam then
                    if bIsAI then botPlayers = botPlayers + 1
                    else realPlayers = realPlayers + 1 end
                end
            end
        end
    end
    if RedBoxOverlay.bActive then RedBoxOverlay.SetCounts(realPlayers, botPlayers)
    else RedBoxOverlay.Start() end
    if PlayerMapMarker.bUseScreenESP then PlayerMapMarker.UpdateESP(AllChars, MyLoc) end
    return 0
end

function PlayerMapMarker.AttachTimers()
    pcall(function()
        local pc = PlayerMapMarker.GetMyPlayerController()
        if not slua.isValid(pc) or not pc.AddGameTimer then
            local now = os.time()
            if PlayerMapMarker._AttachPending then if PlayerMapMarker._AttachPendingTime and (now - PlayerMapMarker._AttachPendingTime) < 2 then return end end
            PlayerMapMarker._AttachPending = true; PlayerMapMarker._AttachPendingTime = now
            pcall(function() require("timer").SetGameTimer(1.0, false, function() PlayerMapMarker._AttachPending = nil; PlayerMapMarker._AttachPendingTime = nil; PlayerMapMarker.AttachTimers() end) end)
            return
        end
        PlayerMapMarker._AttachPending = nil; PlayerMapMarker._AttachPendingTime = nil
        local now = os.time()
        local lastPC = PlayerMapMarker._ActiveTimerPC
        local lastTick = PlayerMapMarker._ActiveTimerTick
        if lastPC and slua.isValid(lastPC) and lastPC == pc then if lastTick and (now - lastTick) < 5 then return end end
        PlayerMapMarker._ActiveTimerPC = pc; PlayerMapMarker._ActiveTimerTick = now
        pcall(function() pc:AddGameTimer(PlayerMapMarker.nUpdateInterval or 0.5, true, function() PlayerMapMarker._ActiveTimerTick = os.time() if PlayerMapMarker.bActive then pcall(function() PlayerMapMarker.ScanAndUpdate() end) end end) end)
        pcall(function() pc:AddGameTimer(PlayerMapMarker._LightUpdateInterval or 0.02, true, function() PlayerMapMarker._ActiveTimerTick = os.time() if PlayerMapMarker.bActive then pcall(function() PlayerMapMarker.UpdateESPLight() end) end end) end)
        pcall(function() require("timer").SetGameTimer(5.0, false, PlayerMapMarker.AttachTimers) end)
    end)
end

function PlayerMapMarker.Start()
    if PlayerMapMarker.bActive then return end
    PlayerMapMarker.bActive = true
    PlayerMapMarker.ScanAndUpdate()
    PlayerMapMarker.AttachTimers()
    if _G.CreditText then pcall(function() _G.CreditText.Start() end) end
end

function PlayerMapMarker.Stop()
    PlayerMapMarker.bActive = false
    PlayerMapMarker.ClearAllESP()
end

_G.PlayerMapMarker = PlayerMapMarker

-- ============ FOV CIRCLE + GROUND CIRCLE ============
PlayerMapMarker.FOVCircleWidget = nil
PlayerMapMarker.GroundCircleWidget = nil
PlayerMapMarker.bShowFOVCircle = true
PlayerMapMarker.bShowGroundCircle = true
PlayerMapMarker.FOVRadius = 150
PlayerMapMarker.FOVColor = FLinearColor and FLinearColor(0.0, 1.0, 0.0, 0.8) or {R=0, G=255, B=0, A=200}
PlayerMapMarker.FOVThickness = 2
PlayerMapMarker.GroundRadius = 2000
PlayerMapMarker.GroundColor = FLinearColor and FLinearColor(0.0, 1.0, 0.0, 0.7) or {R=0, G=255, B=0, A=180}
PlayerMapMarker.GroundThickness = 2
PlayerMapMarker.GroundSegments = 48

function PlayerMapMarker.CreateFOVCircle()
    if PlayerMapMarker.FOVCircleWidget and slua.isValid(PlayerMapMarker.FOVCircleWidget) then return end
    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return end
    local Widgets = {}
    for i = 1, 64 do
        local Border = nil
        pcall(function() Border = CGame:NewObjectFromPath("/Script/UMG.Border", PlayerMapMarker.ESPCanvas) end)
        if Border and slua.isValid(Border) then
            pcall(function()
                Border:SetBrushColor(PlayerMapMarker.FOVColor)
                Border:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                Border.RenderTransformPivot = FVector2D and FVector2D(0.0, 0.5) or {X=0, Y=0.5}
            end)
            local Slot = nil
            pcall(function() Slot = PlayerMapMarker.ESPCanvas:AddChildToCanvas(Border) if Slot then Slot:SetAutoSize(false) Slot:SetZOrder(3) end end)
            if Slot then Widgets[i] = { Widget = Border, Slot = Slot, posVec = FVector2D and FVector2D(0,0) or {X=0,Y=0}, sizeVec = FVector2D and FVector2D(0,0) or {X=0,Y=0} } end
        end
    end
    PlayerMapMarker.FOVCircleWidget = Widgets
end

function PlayerMapMarker.UpdateFOVCircle()
    if not PlayerMapMarker.bShowFOVCircle then
        if PlayerMapMarker.FOVCircleWidget then
            for _, W in pairs(PlayerMapMarker.FOVCircleWidget) do
                if W.Widget and slua.isValid(W.Widget) then W.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end
            end
        end
        return
    end
    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return end
    if not PlayerMapMarker.FOVCircleWidget then PlayerMapMarker.CreateFOVCircle() end
    if not PlayerMapMarker.FOVCircleWidget then return end
    local PC = PlayerMapMarker.GetMyPlayerController()
    if not IsValid(PC) then return end
    local screenW, screenH = 0, 0
    pcall(function()
        if PC.GetViewportSize then
            local vs = FVector2D and FVector2D(0, 0) or {X=0,Y=0}
            PC:GetViewportSize(vs)
            if vs and vs.X and vs.X > 200 then screenW = vs.X screenH = vs.Y end
        end
    end)
    if screenW <= 200 then screenW = PlayerMapMarker._cachedViewportW or 1920 end
    if screenH <= 200 then screenH = PlayerMapMarker._cachedViewportH or 1080 end
    local centerPixelX = screenW / 2
    local centerPixelY = screenH / 2
    local centerCanvasX, centerCanvasY = PlayerMapMarker.ScreenPixelToCanvasLocalRaw(PC, centerPixelX, centerPixelY)
    local radius = PlayerMapMarker.FOVRadius or 150
    local thickness = PlayerMapMarker.FOVThickness or 2
    local segments = 64
    for i = 1, segments do
        local W = PlayerMapMarker.FOVCircleWidget[i]
        if W and W.Widget and W.Slot then
            local angle1 = (i - 1) * (2 * math.pi / segments)
            local angle2 = i * (2 * math.pi / segments)
            local x1 = centerCanvasX + radius * math.cos(angle1)
            local y1 = centerCanvasY + radius * math.sin(angle1)
            local x2 = centerCanvasX + radius * math.cos(angle2)
            local y2 = centerCanvasY + radius * math.sin(angle2)
            local dx = x2 - x1
            local dy = y2 - y1
            local length = math.sqrt(dx * dx + dy * dy)
            local angleRad = (math.atan2 and math.atan2(dy, dx)) or math.atan(dy, dx)
            local angleDeg = angleRad * 57.29577951308232
            pcall(function()
                W.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                W.posVec.X = x1; W.posVec.Y = y1 - thickness / 2.0
                W.Slot:SetPosition(W.posVec)
                W.sizeVec.X = length; W.sizeVec.Y = thickness
                W.Slot:SetSize(W.sizeVec)
                W.Widget:SetRenderAngle(angleDeg)
            end)
        end
    end
end

function PlayerMapMarker.CreateGroundCircle()
    if PlayerMapMarker.GroundCircleWidget and #PlayerMapMarker.GroundCircleWidget > 0 then return end
    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return end
    local Widgets = {}
    local segments = PlayerMapMarker.GroundSegments or 48
    for i = 1, segments do
        local Border = nil
        pcall(function() Border = CGame:NewObjectFromPath("/Script/UMG.Border", PlayerMapMarker.ESPCanvas) end)
        if Border and slua.isValid(Border) then
            pcall(function()
                Border:SetBrushColor(PlayerMapMarker.GroundColor)
                Border:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                Border.RenderTransformPivot = FVector2D and FVector2D(0.0, 0.5) or {X=0, Y=0.5}
            end)
            local Slot = nil
            pcall(function() Slot = PlayerMapMarker.ESPCanvas:AddChildToCanvas(Border) if Slot then Slot:SetAutoSize(false) Slot:SetZOrder(3) end end)
            if Slot then Widgets[i] = { Widget = Border, Slot = Slot, posVec = FVector2D and FVector2D(0,0) or {X=0,Y=0}, sizeVec = FVector2D and FVector2D(0,0) or {X=0,Y=0} } end
        end
    end
    PlayerMapMarker.GroundCircleWidget = Widgets
end

function PlayerMapMarker.UpdateGroundCircle()
    if not PlayerMapMarker.bShowGroundCircle then
        if PlayerMapMarker.GroundCircleWidget then
            for _, W in pairs(PlayerMapMarker.GroundCircleWidget) do
                if W.Widget and slua.isValid(W.Widget) then W.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end
            end
        end
        return
    end
    if not PlayerMapMarker.ESPCanvas or not Game:IsValid(PlayerMapMarker.ESPCanvas) then return end
    if not PlayerMapMarker.GroundCircleWidget then PlayerMapMarker.CreateGroundCircle() end
    if not PlayerMapMarker.GroundCircleWidget then return end
    local PC = PlayerMapMarker.GetMyPlayerController()
    if not IsValid(PC) then return end
    local MyLoc = PlayerMapMarker.GetMyLocation()
    if not MyLoc then return end
    local radius = PlayerMapMarker.GroundRadius or 2000
    local thickness = PlayerMapMarker.GroundThickness or 2
    local segments = PlayerMapMarker.GroundSegments or 48
    for i = 1, segments do
        local W = PlayerMapMarker.GroundCircleWidget[i]
        if W and W.Widget and W.Slot then
            local angle1 = (i - 1) * (2 * math.pi / segments)
            local angle2 = i * (2 * math.pi / segments)
            local wx1 = (MyLoc.X or 0) + radius * math.cos(angle1)
            local wy1 = (MyLoc.Y or 0) + radius * math.sin(angle1)
            local wx2 = (MyLoc.X or 0) + radius * math.cos(angle2)
            local wy2 = (MyLoc.Y or 0) + radius * math.sin(angle2)
            local wz = MyLoc.Z or 0
            local pt1 = {X = wx1, Y = wy1, Z = wz}
            local pt2 = {X = wx2, Y = wy2, Z = wz}
            local ok1, c1x, c1y = PlayerMapMarker.ProjectWorldToCanvasLocalRaw(PC, pt1)
            local ok2, c2x, c2y = PlayerMapMarker.ProjectWorldToCanvasLocalRaw(PC, pt2)
            if ok1 and ok2 then
                local dx = c2x - c1x
                local dy = c2y - c1y
                local length = math.sqrt(dx * dx + dy * dy)
                if length > 0 and length < 3000 then
                    local angleRad = (math.atan2 and math.atan2(dy, dx)) or math.atan(dy, dx)
                    local angleDeg = angleRad * 57.29577951308232
                    pcall(function()
                        W.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                        W.posVec.X = c1x; W.posVec.Y = c1y - thickness / 2.0
                        W.Slot:SetPosition(W.posVec)
                        W.sizeVec.X = length; W.sizeVec.Y = thickness
                        W.Slot:SetSize(W.sizeVec)
                        W.Widget:SetRenderAngle(angleDeg)
                    end)
                else
                    pcall(function() W.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
                end
            else
                pcall(function() W.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
            end
        end
    end
end

function PlayerMapMarker.ClearFOVAndGroundCircles()
    if PlayerMapMarker.FOVCircleWidget then
        for _, W in pairs(PlayerMapMarker.FOVCircleWidget) do
            if W.Widget and slua.isValid(W.Widget) then
                pcall(function() W.Widget:RemoveFromParent() W.Widget:ConditionalBeginDestroy() end)
            end
        end
        PlayerMapMarker.FOVCircleWidget = nil
    end
    if PlayerMapMarker.GroundCircleWidget then
        for _, W in pairs(PlayerMapMarker.GroundCircleWidget) do
            if W.Widget and slua.isValid(W.Widget) then
                pcall(function() W.Widget:RemoveFromParent() W.Widget:ConditionalBeginDestroy() end)
            end
        end
        PlayerMapMarker.GroundCircleWidget = nil
    end
end

-- ============ CREDIT TEXT ============
local CreditText = {
    bActive = false,
    NameContainer = nil,
    InfoContainer = nil,
    NameText = nil,
    DeviceText = nil,
    ExpiryText = nil,
    NameSlot = nil,
    InfoSlot = nil,
    _cachedNamePos = nil,
    _cachedInfoPos = nil,
    Text = "TG BY ~ @ASURVIPMOD",
    DeviceLabel = "ANDROID DEVICE",
    FontSize = 20,
    NameR = 0.0, NameG = 1.0, NameB = 0.0,
    DeviceR = 0.0, DeviceG = 1.0, DeviceB = 0.0,
    ExpiryR = 0.0, ExpiryG = 1.0, ExpiryB = 0.0,
    _lastRenderedName = "",
    _lastRenderedDevice = "",
    _lastRenderedExpiry = "",
    _lastExpiryUpdateSec = 0,
    NameOffsetY = 10,
    InfoScreenOffsetY = 40,
    LineHeight = 28,
    InfoLeftMargin = 40,
    InfoBottomMargin = 0,
    ManualYShift = 60,
    ContainerWidth = 800,
    ContainerHeight = 120,
}

local function DetectDeviceName()
    local deviceName = nil
    pcall(function()
        local build = import("AndroidBuildInfo") or import("/Script/AndroidRuntimeSettings.AndroidBuildInfo")
        if build and build.DeviceModel and build.DeviceModel ~= "" then
            deviceName = build.DeviceModel
        end
    end)
    pcall(function()
        if not deviceName then
            local sysLib = import("KismetSystemLibrary")
            if sysLib and sysLib.GetDeviceName then deviceName = sysLib:GetDeviceName() end
        end
    end)
    pcall(function()
        if not deviceName then
            local platform = import("GameplayStatics")
            if platform and platform.GetDeviceName then deviceName = platform:GetDeviceName() end
        end
    end)
    pcall(function()
        if not deviceName and CGame and CGame.GetDeviceName then
            deviceName = CGame:GetDeviceName()
        end
    end)
    if not deviceName or deviceName == "" then deviceName = "ANDROID DEVICE" end
    return deviceName
end

local function GetExpiryDateTimeString()
    local now = os.time(os.date("!*t"))
    pcall(function()
        local tm = package.loaded["client.logic.common.TimeManager"]
        if not tm then 
            local s, r = pcall(require, "client.logic.common.TimeManager")
            if s and r then tm = r end 
        end
        if tm and type(tm.GetServerTime) == "function" then
            local serverTime = tm.GetServerTime()
            if serverTime and serverTime > 1700000000 then now = serverTime end
        end
    end)

    local expireTime = nil
    pcall(function()
        expireTime = sessionExpireTime 
            or (CGame and CGame.sessionExpireTime) 
            or (rawget(_G, "sessionExpireTime"))
    end)

    if not expireTime or type(expireTime) ~= "number" or expireTime <= 0 then
        expireTime = now + 86400 * 30
    end
    if now >= expireTime then expireTime = now end

    local dt = os.date("!*t", expireTime)
    return string.format("EXPIRY %04d-%02d-%02d-%02d:%02d:%02d",
        dt.year, dt.month, dt.day, dt.hour, dt.min, dt.sec)
end

function CreditText.Create()
    local bNameReady = CreditText.NameContainer and slua.isValid(CreditText.NameContainer)
    local bInfoReady = CreditText.InfoContainer and slua.isValid(CreditText.InfoContainer)
    if bNameReady and bInfoReady then return true end

    local ParentCanvas = PlayerMapMarker.ESPCanvas
    if not ParentCanvas or not slua.isValid(ParentCanvas) then
        if not PlayerMapMarker.InitESPCanvas() then return false end
        ParentCanvas = PlayerMapMarker.ESPCanvas
    end
    if not ParentCanvas or not slua.isValid(ParentCanvas) then return false end

    local FLinearColor = import("LinearColor") or FLinearColor
    local FSlateColor  = import("SlateColor") or import("/Script/SlateCore.SlateColor")
    local FVector2D    = import("Vector2D") or FVector2D

    CreditText.DeviceLabel = DetectDeviceName()

    if not bNameReady then
        local nameTxt = nil
        pcall(function() nameTxt = CGame:NewObjectFromPath("/Script/UMG.TextBlock", ParentCanvas) end)
        if nameTxt and slua.isValid(nameTxt) then
            pcall(function()
                nameTxt:SetText(CreditText.Text)
                local col = FLinearColor(CreditText.NameR, CreditText.NameG, CreditText.NameB, 1.0)
                if FSlateColor then nameTxt:SetColorAndOpacity(FSlateColor(col)) else nameTxt:SetColorAndOpacity(col) end
                if nameTxt.Font then local f = nameTxt.Font; f.Size = CreditText.FontSize; nameTxt.Font = f end
                nameTxt:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            end)
            local nslot = nil
            pcall(function() nslot = ParentCanvas:AddChildToCanvas(nameTxt) end)
            if nslot then
                pcall(function()
                    nslot:SetAutoSize(true)
                    nslot:SetAlignment(FVector2D(0.5, 0.0))
                    nslot:SetPosition(FVector2D(0, 0))
                    nslot:SetZOrder(5000)
                end)
                CreditText.NameContainer = nameTxt
                CreditText.NameText = nameTxt
                CreditText.NameSlot = nslot
            end
        end
    end

    if not bInfoReady then
        local Container = nil
        pcall(function() Container = CGame:NewObjectFromPath("/Script/UMG.CanvasPanel", ParentCanvas) end)
        if Container and slua.isValid(Container) then
            local devTxt = nil
            pcall(function() devTxt = CGame:NewObjectFromPath("/Script/UMG.TextBlock", Container) end)
            if devTxt and slua.isValid(devTxt) then
                pcall(function()
                    devTxt:SetText(CreditText.DeviceLabel)
                    local col = FLinearColor(CreditText.DeviceR, CreditText.DeviceG, CreditText.DeviceB, 1.0)
                    if FSlateColor then devTxt:SetColorAndOpacity(FSlateColor(col)) else devTxt:SetColorAndOpacity(col) end
                    if devTxt.Font then local f = devTxt.Font; f.Size = CreditText.FontSize; devTxt.Font = f end
                    devTxt:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                end)
                local dslot = Container:AddChildToCanvas(devTxt)
                if dslot then pcall(function()
                    dslot:SetAutoSize(true)
                    dslot:SetAlignment(FVector2D(0.0, 0.0))
                    dslot:SetPosition(FVector2D(0, 0))
                    dslot:SetZOrder(100)
                end) end
            end

            local expTxt = nil
            pcall(function() expTxt = CGame:NewObjectFromPath("/Script/UMG.TextBlock", Container) end)
            if expTxt and slua.isValid(expTxt) then
                pcall(function()
                    expTxt:SetText(GetExpiryDateTimeString())
                    local col = FLinearColor(CreditText.ExpiryR, CreditText.ExpiryG, CreditText.ExpiryB, 1.0)
                    if FSlateColor then expTxt:SetColorAndOpacity(FSlateColor(col)) else expTxt:SetColorAndOpacity(col) end
                    if expTxt.Font then local f = expTxt.Font; f.Size = CreditText.FontSize; expTxt.Font = f end
                    expTxt:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                end)
                local eslot = Container:AddChildToCanvas(expTxt)
                if eslot then pcall(function()
                    eslot:SetAutoSize(true)
                    eslot:SetAlignment(FVector2D(0.0, 0.0))
                    eslot:SetPosition(FVector2D(0, CreditText.LineHeight))
                    eslot:SetZOrder(100)
                end) end
            end

            local mainSlot = nil
            pcall(function() mainSlot = ParentCanvas:AddChildToCanvas(Container) end)
            if mainSlot then
                pcall(function()
                    mainSlot:SetAutoSize(false)
                    mainSlot:SetAlignment(FVector2D(0.0, 1.0))
                    mainSlot:SetPosition(FVector2D(0, 0))
                    mainSlot:SetSize(FVector2D(CreditText.ContainerWidth, CreditText.ContainerHeight))
                    mainSlot:SetZOrder(5000)
                end)
                CreditText.InfoContainer = Container
                CreditText.DeviceText = devTxt
                CreditText.ExpiryText = expTxt
                CreditText.InfoSlot = mainSlot
            end
        end
    end

    CreditText.UpdatePosition()
    return true
end

function CreditText.UpdateText()
    if CreditText.NameText and slua.isValid(CreditText.NameText) then
        if CreditText._lastRenderedName ~= CreditText.Text then
            CreditText._lastRenderedName = CreditText.Text
            pcall(function() CreditText.NameText:SetText(CreditText.Text) end)
        end
    end

    if CreditText.DeviceText and slua.isValid(CreditText.DeviceText) then
        if CreditText._lastRenderedDevice ~= CreditText.DeviceLabel then
            CreditText._lastRenderedDevice = CreditText.DeviceLabel
            pcall(function() CreditText.DeviceText:SetText(CreditText.DeviceLabel) end)
        end
    end

    local nowSec = os.time()
    if nowSec - (CreditText._lastExpiryUpdateSec or 0) >= 1 then
        CreditText._lastExpiryUpdateSec = nowSec
        local newExpiry = GetExpiryDateTimeString()
        if CreditText.ExpiryText and slua.isValid(CreditText.ExpiryText) then
            pcall(function() 
                CreditText.ExpiryText:SetText(newExpiry) 
            end)
        end
        CreditText._lastRenderedExpiry = newExpiry
    end
end

function CreditText.UpdatePosition()
    local PC = PlayerMapMarker.GetMyPlayerController()
    if not slua.isValid(PC) then return end

    local screenW, screenH = 0, 0
    local scale = 1.0
    pcall(function()
        if PC and PC.GetViewportSize then
            local vs = FVector2D and FVector2D(0, 0) or {X=0, Y=0}
            PC:GetViewportSize(vs)
            if vs and vs.X and vs.X > 200 then screenW = vs.X screenH = vs.Y end
        end
    end)
    if screenW <= 200 then
        pcall(function()
            local WLL = WidgetLayoutLibrary
            if WLL and WLL.GetViewportSize then
                local vs = WLL.GetViewportSize(PC)
                if vs and vs.X and vs.X > 200 then screenW = vs.X screenH = vs.Y end
            end
        end)
    end
    if screenW <= 200 then screenW = (PlayerMapMarker._cachedViewportW or 1920) end
    if screenH <= 200 then screenH = (PlayerMapMarker._cachedViewportH or 1080) end

    pcall(function()
        local WLL = WidgetLayoutLibrary
        if WLL and WLL.GetViewportScale then
            local s = WLL.GetViewportScale(PC)
            if s and type(s) == "number" and s > 0 then scale = s end
        end
    end)

    local FVector2D = import("Vector2D") or FVector2D

    if CreditText.NameSlot and slua.isValid(CreditText.NameSlot) then
        local centerScreenX = screenW * 0.5
        local snapFromX, snapFromY = PlayerMapMarker.GetSnapLineStartPos(PC)
        local baseY = snapFromY + ((RedBoxOverlay and RedBoxOverlay.OffsetY) or -8) + 22 * scale
        local canvasY = baseY + (CreditText.NameOffsetY or 10) * scale
        local centerCanvasX = centerScreenX * (PlayerMapMarker._CanvasScaleX or 1.0) + (PlayerMapMarker._CanvasOffsetX or 0)
        pcall(function()
            if not CreditText._cachedNamePos then CreditText._cachedNamePos = FVector2D(centerCanvasX, canvasY) end
            CreditText._cachedNamePos.X = centerCanvasX
            CreditText._cachedNamePos.Y = canvasY
            CreditText.NameSlot:SetPosition(CreditText._cachedNamePos)
        end)
    end

    if CreditText.InfoSlot and slua.isValid(CreditText.InfoSlot) then
        local leftScreenX = (CreditText.InfoLeftMargin or 40) * scale
        local bottomScreenY = screenH - ((CreditText.InfoBottomMargin or 0) * scale)

        local canvasX, canvasY = PlayerMapMarker.ScreenPixelToCanvasLocalRaw(PC, leftScreenX, bottomScreenY)

        canvasY = canvasY + (CreditText.ManualYShift or 60)

        pcall(function()
            if not CreditText._cachedInfoPos then CreditText._cachedInfoPos = FVector2D(canvasX, canvasY) end
            CreditText._cachedInfoPos.X = canvasX
            CreditText._cachedInfoPos.Y = canvasY
            CreditText.InfoSlot:SetPosition(CreditText._cachedInfoPos)
        end)
    end

    CreditText.UpdateText()
end

function CreditText.Start()
    if CreditText.bActive then
        local bNameReady = CreditText.NameContainer and slua.isValid(CreditText.NameContainer)
        local bInfoReady = CreditText.InfoContainer and slua.isValid(CreditText.InfoContainer)
        if bNameReady and bInfoReady then return end
    end
    if CreditText.Create() then
        CreditText.bActive = true
        if CreditText.NameContainer and slua.isValid(CreditText.NameContainer) then
            pcall(function() CreditText.NameContainer:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
        end
        if CreditText.InfoContainer and slua.isValid(CreditText.InfoContainer) then
            pcall(function() CreditText.InfoContainer:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
        end
    end
end

function CreditText.Stop()
    CreditText.bActive = false
    if CreditText.NameContainer and slua.isValid(CreditText.NameContainer) then
        pcall(function() CreditText.NameContainer:RemoveFromParent() CreditText.NameContainer:ConditionalBeginDestroy() end)
    end
    if CreditText.InfoContainer and slua.isValid(CreditText.InfoContainer) then
        pcall(function() CreditText.InfoContainer:RemoveFromParent() CreditText.InfoContainer:ConditionalBeginDestroy() end)
    end
    CreditText.NameContainer = nil
    CreditText.InfoContainer = nil
    CreditText.NameText = nil
    CreditText.DeviceText = nil
    CreditText.ExpiryText = nil
    CreditText.NameSlot = nil
    CreditText.InfoSlot = nil
    CreditText._cachedNamePos = nil
    CreditText._cachedInfoPos = nil
    CreditText._lastRenderedName = ""
    CreditText._lastRenderedDevice = ""
    CreditText._lastRenderedExpiry = ""
    CreditText._lastExpiryUpdateSec = 0
end

_G.CreditText = CreditText

-- ============================================================
-- AIMBOT V2 MAIN FUNCTION (merged from top.lua)
-- ============================================================
_G.AimTouch = function()
    pcall(function()
        if not _G.XthrlenConfig.AimTouchEnable then return end

        local player = GameplayData.GetPlayerCharacter()
        if not (slua and slua.isValid and slua.isValid(player)) then return end

        local pc = player:GetPlayerControllerSafety()
        if not (slua and slua.isValid and slua.isValid(pc)) then return end

        local isFiring = player.bIsWeaponFiring
        local isADS = player.bIsGunADS

        local weapon = player.WeaponManagerComponent and player.WeaponManagerComponent.CurrentWeaponReplicated
        if not weapon and type(player.GetCurrentShootWeapon) == "function" then
            weapon = player:GetCurrentShootWeapon()
        end

        local isShotgun = false
        local isSniper = false
        local isMortar = false
        local currentAmmo = 1

        if slua.isValid(weapon) then
            local wID = type(weapon.GetWeaponID) == "function" and weapon:GetWeaponID() or 0
            local wName = type(weapon.GetWeaponName) == "function" and weapon:GetWeaponName() or ""

            if (wID >= 1030000 and wID < 1040000) or wName:find("S686") or wName:find("S1897")
                or wName:find("S12") or wName:find("DBS") or wName:find("M1014") then
                isShotgun = true
            end
            if wName:find("Kar98") or wName:find("M24") or wName:find("AWM") or wName:find("Mosin")
                or wName:find("Win94") or wName:find("AMR") or wName:find("SKS") or wName:find("SLR")
                or wName:find("Mini") or wName:find("Mk14") or wName:find("QBU") or wName:find("Mk12")
                or wName:find("VSS") then
                isSniper = true
            end
            if wName:lower():find("mortar") or wName:lower():find("cối") then
                isMortar = true
            end

            if type(weapon.GetCurrentAmmo) == "function" then
                currentAmmo = weapon:GetCurrentAmmo()
            elseif weapon.ShootWeaponComponent and type(weapon.ShootWeaponComponent.GetCurrentAmmo) == "function" then
                currentAmmo = weapon.ShootWeaponComponent:GetCurrentAmmo()
            elseif weapon.CurrentAmmo ~= nil then
                currentAmmo = weapon.CurrentAmmo
            end
        end

        if _G.XthrlenState.IsAutoFiring then
            pcall(function()
                player.bIsWeaponFiring = false
                if type(player.SetIsWeaponFiring) == "function" then player:SetIsWeaponFiring(false) end
                if slua.isValid(pc) and type(pc.SetIsWeaponFiring) == "function" then pc:SetIsWeaponFiring(false) end
                local wepMgr = player.WeaponManagerComponent
                if slua.isValid(wepMgr) then wepMgr.bIsWeaponFiring = false end
            end)
            _G.XthrlenState.IsAutoFiring = false
        end

        if isShotgun and currentAmmo <= 0 then return end

        local cond = 2
        local prioMode = 1
        local boneIdx = 1
        local speedVal = 100
        local fovVal = 30
        local maxDistMeters = 100
        local useVisCheck = false
        local igKnock = false
        local igBot = false
        local predVal = 0

        if isMortar and _G.XthrlenConfig.AimTouchMortar then
            local isPlaced = false
            pcall(function()
                if weapon and weapon.MortarState == 2 then isPlaced = true end
            end)
            if not isPlaced then return end

            cond = 2
            prioMode = 1
            boneIdx = 4
            speedVal = 100
            fovVal = _G.XthrlenState.CustomTextData.AimTouchMortarFOV or 360
            maxDistMeters = 2000
            useVisCheck = false
            igKnock = false
            igBot = false
            predVal = _G.XthrlenState.CustomTextData.AimTouchMortarPred or 0

        elseif isShotgun and _G.XthrlenConfig.AimTouchSG then
            cond = _G.XthrlenState.CustomTextData.AimTouchSGCond or 1
            if _G.XthrlenConfig.AimTouchSGAutoFire then cond = 2 end
            if cond == 1 and not isFiring then return end
            prioMode = _G.XthrlenState.CustomTextData.AimTouchSGPrio or 1
            boneIdx = _G.XthrlenState.CustomTextData.AimTouchSGBone or 2
            speedVal = _G.XthrlenState.CustomTextData.AimTouchSGSpeed or 80
            fovVal = _G.XthrlenState.CustomTextData.AimTouchSGFOV or 40
            maxDistMeters = _G.XthrlenState.CustomTextData.AimTouchSGDist or 30
            useVisCheck = _G.XthrlenConfig.AimTouchSGVisCheck
            igKnock = _G.XthrlenConfig.AimTouchSGIgKnock
            igBot = _G.XthrlenConfig.AimTouchSGIgBot

        elseif isADS then
            if isSniper and _G.XthrlenConfig.AimTouchScopeSniper then
                cond = _G.XthrlenState.CustomTextData.AimTouchSniperCond or 2
                if cond == 1 and not isFiring then return end
                prioMode = _G.XthrlenState.CustomTextData.AimTouchSniperPrio or 1
                boneIdx = _G.XthrlenState.CustomTextData.AimTouchSniperBone or 1
                speedVal = _G.XthrlenState.CustomTextData.AimTouchSniperSpeed or 30
                fovVal = _G.XthrlenState.CustomTextData.AimTouchSniperFOV or 20
                maxDistMeters = _G.XthrlenState.CustomTextData.AimTouchSniperDist or 400
                useVisCheck = _G.XthrlenConfig.AimTouchSniperVisCheck
                igKnock = _G.XthrlenConfig.AimTouchSniperIgKnock
                igBot = _G.XthrlenConfig.AimTouchSniperIgBot
                predVal = _G.XthrlenState.CustomTextData.AimTouchSniperPred or 0
            elseif _G.XthrlenConfig.AimTouchScopeAll then
                cond = _G.XthrlenState.CustomTextData.AimTouchScopeCond or 1
                if cond == 1 and not isFiring then return end
                prioMode = _G.XthrlenState.CustomTextData.AimTouchScopePrio or 1
                boneIdx = 1
                speedVal = _G.XthrlenState.CustomTextData.AimTouchScopeSpeed or 100
                fovVal = _G.XthrlenState.CustomTextData.AimTouchScopeFOV or 30
                maxDistMeters = _G.XthrlenState.CustomTextData.AimTouchScopeDist or 100
                useVisCheck = _G.XthrlenConfig.AimTouchScopeVisCheck
                igKnock = _G.XthrlenConfig.AimTouchScopeIgKnock
                igBot = _G.XthrlenConfig.AimTouchScopeIgBot
                predVal = _G.XthrlenState.CustomTextData.AimTouchScopePred or 0
            else
                return
            end

        else
            if not _G.XthrlenConfig.AimTouchHipfire then return end
            cond = _G.XthrlenState.CustomTextData.AimTouchHipCond or 1
            if cond == 1 and not isFiring then return end
            prioMode = _G.XthrlenState.CustomTextData.AimTouchHipPrio or 1
            boneIdx = 1
            speedVal = _G.XthrlenState.CustomTextData.AimTouchHipSpeed or 100
            fovVal = _G.XthrlenState.CustomTextData.AimTouchHipFOV or 30
            maxDistMeters = _G.XthrlenState.CustomTextData.AimTouchHipDist or 100
            useVisCheck = _G.XthrlenConfig.AimTouchHipVisCheck
            igKnock = _G.XthrlenConfig.AimTouchHipIgKnock
            igBot = _G.XthrlenConfig.AimTouchHipIgBot
        end

        local currentMaxDist = maxDistMeters * 100
        local enemies = _G.GetEnemyTargetsFromActors(currentMaxDist)
        if not enemies or #enemies == 0 then return end

        local FVector2D = import("Vector2D")
        local UGameplayStatics = import("GameplayStatics")
        local KismetMathLibrary = import("KismetMathLibrary")

        local camManager = UGameplayStatics.GetPlayerCameraManager(pc, 0)
        if not slua.isValid(camManager) then return end

        local camLoc = camManager:GetCameraLocation()
        if not camLoc then return end

        local ui_util = require("client.common.ui_util")
        if not ui_util then return end

        local viewportSize = ui_util.GetViewportSize()
        if not viewportSize then return end

        local centerX = viewportSize.X * 0.5
        local centerY = viewportSize.Y * 0.5
        local FOV_RADIUS = (fovVal / 100.0) * (viewportSize.X / 2.0)

        local bestTarget = nil
        local bestScore = 99999999

        local selBoneName = "spine_03"
        if boneIdx == 1 then selBoneName = "spine_03"
        elseif boneIdx == 2 then selBoneName = "spine_03"
        elseif boneIdx == 3 then selBoneName = "spine_01"
        elseif boneIdx == 4 then selBoneName = "pelvis" end

        for i, target in ipairs(enemies) do
            if not slua.isValid(target) then goto continue end

            pcall(function()
                if slua.isValid(target.Mesh) then
                    target.Mesh.MeshComponentUpdateFlag = 0
                end
            end)

            if igKnock and target.HealthStatus == 1 then goto continue end

            if igBot then
                local tIsBot = false
                if target.bIsAI == true or target.IsAI == true then tIsBot = true end
                local pState = target.PlayerState
                if slua.isValid(pState) and (pState.bIsABot or pState.bIsBot) then tIsBot = true end
                if tIsBot then goto continue end
            end

            if useVisCheck then
                local curTime = os.clock()
                local tId = type(target.GetUniqueID) == "function" and target:GetUniqueID() or tostring(target)
                _G.AimTouchVisCache = _G.AimTouchVisCache or {}
                if not _G.AimTouchVisCache[tId] or (curTime - _G.AimTouchVisCache[tId].time) > 0.2 then
                    local isHidden = true
                    pcall(function() if pc:LineOfSightTo(target) then isHidden = false end end)
                    _G.AimTouchVisCache[tId] = { hidden = isHidden, time = curTime }
                end
                if _G.AimTouchVisCache[tId].hidden then goto continue end
            end

            local tPos = target:GetBonePos(selBoneName, {X=0, Y=0, Z=0})
            if not tPos or (tPos.X == 0 and tPos.Y == 0 and tPos.Z == 0) then
                if type(target.GetSocketLocation) == "function" then
                    tPos = target:GetSocketLocation(selBoneName)
                end
            end
            if not tPos or (tPos.X == 0 and tPos.Y == 0 and tPos.Z == 0) then
                if type(target.K2_GetActorLocation) == "function" then
                    tPos = target:K2_GetActorLocation()
                    if tPos then
                        if boneIdx == 1 then tPos.Z = tPos.Z + 40
                        elseif boneIdx == 2 then tPos.Z = tPos.Z + 40
                        elseif boneIdx == 3 then tPos.Z = tPos.Z + 20 end
                    end
                end
            end
            if not tPos or (tPos.X == 0 and tPos.Y == 0 and tPos.Z == 0) then goto continue end

            local screen = FVector2D()
            local success = pc:ProjectWorldLocationToScreen(tPos, screen, false)
            if not success or screen.X <= 0 or screen.Y <= 0 then goto continue end

            local dx = screen.X - centerX
            local dy = screen.Y - centerY
            local distScreen = math.sqrt(dx*dx + dy*dy)

            if distScreen > FOV_RADIUS then goto continue end

            local currentScore = distScreen
            if prioMode == 2 then currentScore = player:GetDistanceTo(target)
            elseif prioMode == 3 then currentScore = target.Health or 100
            elseif prioMode == 4 then
                local hp = target.Health or 100
                local maxhp = target.HealthMax or 100
                if maxhp <= 0 then maxhp = 100 end
                currentScore = hp / maxhp
            end

            if currentScore < bestScore then
                bestScore = currentScore
                bestTarget = target
            end

            ::continue::
        end

        if not slua.isValid(bestTarget) then return end

        local finalBonePos = bestTarget:GetBonePos(selBoneName, {X=0, Y=0, Z=0})
        if not finalBonePos or (finalBonePos.X == 0 and finalBonePos.Y == 0 and finalBonePos.Z == 0) then
            if type(bestTarget.GetSocketLocation) == "function" then
                finalBonePos = bestTarget:GetSocketLocation(selBoneName)
            end
        end
        if not finalBonePos or (finalBonePos.X == 0 and finalBonePos.Y == 0 and finalBonePos.Z == 0) then
            if type(bestTarget.K2_GetActorLocation) == "function" then
                finalBonePos = bestTarget:K2_GetActorLocation()
                if finalBonePos then
                    if boneIdx == 1 then finalBonePos.Z = finalBonePos.Z + 40
                    elseif boneIdx == 2 then finalBonePos.Z = finalBonePos.Z + 40
                    elseif boneIdx == 3 then finalBonePos.Z = finalBonePos.Z + 20 end
                end
            end
        end
        if not finalBonePos or (finalBonePos.X == 0 and finalBonePos.Y == 0 and finalBonePos.Z == 0) then return end

        local tVelocity = nil
        pcall(function()
            if type(bestTarget.GetVelocity) == "function" then
                tVelocity = bestTarget:GetVelocity()
            end
        end)

        if not isMortar and predVal > 0 then
            pcall(function()
                if tVelocity and (tVelocity.X ~= 0 or tVelocity.Y ~= 0) then
                    local distToEnemy = player:GetDistanceTo(bestTarget) / 100.0
                    local ToF = (distToEnemy / 800.0) * (predVal / 50.0)
                    finalBonePos.X = finalBonePos.X + (tVelocity.X * ToF)
                    finalBonePos.Y = finalBonePos.Y + (tVelocity.Y * ToF)
                end
            end)
        end

        if isADS and isFiring then
            local dist = player:GetDistanceTo(bestTarget) / 100.0
            finalBonePos.Z = finalBonePos.Z - (dist * 1.1)
        end

        local rot = KismetMathLibrary.FindLookAtRotation(camLoc, finalBonePos)
        if not rot then return end

        local currentRot = pc:GetControlRotation()
        if not currentRot then return end

        local deltaYaw = rot.Yaw - currentRot.Yaw
        local deltaPitch = rot.Pitch - currentRot.Pitch

        if isADS then
            local camRot = nil
            if type(camManager.GetCameraRotation) == "function" then
                camRot = camManager:GetCameraRotation()
            end
            if camRot then
                deltaYaw = deltaYaw - (camRot.Yaw - currentRot.Yaw)
                deltaPitch = deltaPitch - (camRot.Pitch - currentRot.Pitch)
            end
        end

        if deltaYaw > 180 then deltaYaw = deltaYaw - 360 end
        if deltaYaw < -180 then deltaYaw = deltaYaw + 360 end
        if deltaPitch > 180 then deltaPitch = deltaPitch - 360 end
        if deltaPitch < -180 then deltaPitch = deltaPitch + 360 end

        local smoothFactor = 1.0
        if speedVal < 100 then
            smoothFactor = (speedVal / 100.0) * 0.3
            if smoothFactor < 0.01 then smoothFactor = 0.01 end
        end

        local finalPitch = currentRot.Pitch + (deltaPitch * smoothFactor)
        local finalYaw = currentRot.Yaw + (deltaYaw * smoothFactor)

        local finalRot = { Pitch = finalPitch, Yaw = finalYaw, Roll = 0 }
        pc:SetControlRotation(finalRot, "AimTouch")
    end)
end


local function MainLoop()
    if isExpired then return end

    local now = os.time(os.date("!*t"))
    if now - _lastExpiryCheck >= 5 then
        _lastExpiryCheck = now
        if CheckExpiry() then
            if _G.PlayerMapMarker and type(_G.PlayerMapMarker.Stop) == "function" then _G.PlayerMapMarker.Stop() end
            if _G.RedBoxOverlay and type(_G.RedBoxOverlay.Stop) == "function" then _G.RedBoxOverlay.Stop() end
            if _G.CreditText and type(_G.CreditText.Stop) == "function" then _G.CreditText.Stop() end
            if _G._AimTouchTimer then
                local pcA = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
                if slua.isValid(pcA) then pcall(function() pcA:RemoveGameTimer(_G._AimTouchTimer) end) end
                _G._AimTouchTimer = nil
            end
            return
        end
    end

    pcall(function()
        local SystemLib = import("KismetSystemLibrary")
        if SystemLib and not _G.FakeHWID_Hooked then
            _G.Original_GetDeviceId = SystemLib.GetDeviceId
            SystemLib.GetDeviceId = function(...)
                if _G.LexusConfig.FakeHWID then
                    if not _G.FakeHWID_String then
                        local chars = "0123456789abcdef"
                        local hwid = ""
                        for i = 1, 32 do hwid = hwid .. chars:sub(math.random(1, 16), math.random(1, 16)) end
                        _G.FakeHWID_String = hwid
                    end
                    return _G.FakeHWID_String
                end
                if _G.Original_GetDeviceId then return _G.Original_GetDeviceId(...) end
                return "UNKNOWN"
            end
            _G.FakeHWID_Hooked = true
        end
    end)

    if _G.LexusState.CustomTextData == nil then _G.LexusState.CustomTextData = {} end

    local okData, GDP = pcall(require, "GameLua.GameCore.Data.GameplayData")
    if not okData or not GDP then return end
    local pc = GDP.GetPlayerController()
    local localPlayer = nil
    if Valid(pc) then localPlayer = pc:GetPlayerCharacterSafety() end

    if not Valid(localPlayer) then
        if _G.PlayerMapMarker and type(_G.PlayerMapMarker.Stop) == "function" then _G.PlayerMapMarker.Stop() end
        if _G.RedBoxOverlay and type(_G.RedBoxOverlay.Stop) == "function" then _G.RedBoxOverlay.Stop() end
        if _G.CreditText and type(_G.CreditText.Stop) == "function" then _G.CreditText.Stop() end
        return
    end

    if _G.PlayerMapMarker and not _G.PlayerMapMarker.bActive then
        _G.PlayerMapMarker.Start()
    end

    pcall(function()
        if pc.HiggsBoson then pc.HiggsBoson.bMHActive = false; pc.HiggsBoson.bCallPreReplication = false end
        if pc.HiggsBosonComponent then pc.HiggsBosonComponent.bMHActive = false; pc.HiggsBosonComponent.bCallPreReplication = false end
    end)
end

_G.LexusState.LoopToken = (_G.LexusState.LoopToken or 0) + 1
local myToken = _G.LexusState.LoopToken

local function ExpiredTick()
    if not _G.LexusNotifiedPopup then _G.LexusNotifiedPopup = true end
end

local function FastTick()
    if isExpired then
        if not _G.LexusNotifiedExpire then
            _G.LexusNotifiedExpire = true
            ExpiredTick()
        end
        return
    end
    if myToken ~= _G.LexusState.LoopToken then return end
    pcall(MainLoop)
    local okTicker, ticker = pcall(require, "common.time_ticker")
    if okTicker and ticker and ticker.AddTimerOnce then
        ticker.AddTimerOnce(0.01, FastTick)
    end
end

FastTick()

local function InitAllModSystems()
    if isExpired then return end
    pcall(function() if _G.StartBypass_VIP_v3 then _G.StartBypass_VIP_v3() end end)
    local GDP = package.loaded["GameLua.GameCore.Data.GameplayData"] or require("GameLua.GameCore.Data.GameplayData")
    if not GDP then return end
    pcall(function()
        local LocalPlayer = GDP.GetPlayerCharacter and GDP.GetPlayerCharacter()
        if slua.isValid(LocalPlayer) then
            if LocalPlayer.bHasShownDevNotice == nil then
                LocalPlayer.bHasShownDevNotice = false
                LocalPlayer.bHasShownExpiredNotice = false
                LocalPlayer.bIsDeadFlag = false
            end
        end
    end)
end

if not isExpired then
    pcall(function() require("common.time_ticker").AddTimerOnce(0.5, InitAllModSystems) end)
end

-- ============ CLASS REGISTRATION ============
local class = require("class")
local CCharacterBase = require("GameLua.GameCore.Framework.CharacterBase")
local CBRPlayerCharacterBase = class(CCharacterBase, nil, BRPlayerCharacterBase)
return require("combine_class").DeclareFeature(CBRPlayerCharacterBase, {
  { SkyTransition = "GameLua.Mod.BaseMod.Gameplay.Feature.SkyControl.PlayerCharacterSkyTransitionFeature" },
  { CarryDeadBoxFeature = "GameLua.Mod.Library.GamePlay.Feature.CarryDeadBoxFeature" },
  { SpecialSuitFeature = "GameLua.Mod.Library.GamePlay.Feature.SpecialSuitFeature" },
  { TeleportPawnFeature = "GameLua.Mod.Library.GamePlay.Feature.TeleportPawnFeature" },
  { LifterControl = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.CharacterLifterControlFeature" },
  { FinalKillEffect = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.PlayerCharacterFinalKillEffectFeature" },
  { CampFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.Camp.PlayerCharacterCampFeature" },
  { BuildSkateFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.PlayerCharacterBuildVehicleFeature" },
  { CommonBornlandTransformFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.HeroPropFeature.CommonBornlandTransformFeature" },
  { ParachuteFormation = "GameLua.Mod.BaseMod.GamePlay.Feature.ParachuteFormationFeature" },
  { SpiderSenseFootprintFeature = "GameLua.Mod.Library.GamePlay.Feature.SpiderSenseFootprintFeature" },
  { GeneralShowSpotFeature = "GameLua.Mod.BRMod.Gameplay.Feature.PlayerCharacterGeneralShowSpotFeature" }
}, "BRPlayerCharacterBase")
