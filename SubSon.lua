------------------------------------------------------------
-- Spell cache system (performance improvement)
------------------------------------------------------------
local knownSpells = {}

local function HasSpell(name)
    -- Return cached result if available
    if knownSpells[name] ~= nil then
        return knownSpells[name]
    end

    -- Otherwise scan the spellbook once
    local i = 1
    while true do
        local spellName = GetSpellName(i, BOOKTYPE_SPELL)
        if not spellName then
            knownSpells[name] = false
            return false
        end
        if spellName == name then
            knownSpells[name] = true
            return true
        end
        i = i + 1
    end
end

local function ResetSpellCache()
    knownSpells = {}
end

------------------------------------------------------------
-- Simple spell casting
------------------------------------------------------------
local function Cast(name)
    CastSpellByName(name)
end

local function Debug(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF8800SubSon DEBUG:|r " .. msg)
end

------------------------------------------------------------
-- Buff detection using substring matching
------------------------------------------------------------
local function PlayerHasBuffIcon(partial)
    for i = 0, 65 do
        local f = _G["BuffButton"..i]
        if f then
            local r1 = f:GetRegions()
            if r1 and r1.GetTexture then
                local tex = r1:GetTexture()
                if tex and string.find(tex, partial, 1, true) then
                    return true
                end
            end
        end
    end
    return false
end

local function IsInBattleStance()
    return PlayerHasBuffIcon("Ability_Warrior_OffensiveStance")
end

local function IsInDefensiveStance()
    return PlayerHasBuffIcon("Ability_Warrior_DefensiveStance")
end

local function IsInBerserkerStance()
    return PlayerHasBuffIcon("Ability_Racial_Avatar")
end

local function HasBattleShout()
    return PlayerHasBuffIcon("Ability_Warrior_BattleShout")
end

------------------------------------------------------------
-- Utility
------------------------------------------------------------
local function GetRage()
    return UnitMana("player")
end

local function ShouldExecute()
    if not UnitExists("target") then return false end
    return (UnitHealth("target") / UnitHealthMax("target")) < 0.20
end

------------------------------------------------------------
-- Range checks
------------------------------------------------------------
local function InMeleeRange()
    return CheckInteractDistance("target", 3)  -- 9.9 yards
end

local function TooCloseForCharge()
    return CheckInteractDistance("target", 3)  -- melee range
end

------------------------------------------------------------
-- Charge logic
------------------------------------------------------------
local function CanCharge()
    if (not HasSpell("Charge"))
       or UnitAffectingCombat("player")
       or (not UnitExists("target"))
       or UnitIsDead("target")
       or (not UnitCanAttack("player", "target")) then
        return false
    end
    return true
end

------------------------------------------------------------
-- Auto-target + auto-attack
------------------------------------------------------------
local function WarriorAutoAttackStart()

    if UnitExists("target") and UnitIsFriend("player", "target") then
        if HasSpell("Intervene") then
            if not IsInDefensiveStance() then
                Cast("Defensive Stance")
                return
            end
            Cast("Intervene")
            return
        end
        return
    end

    if not UnitExists("target") or UnitIsDeadOrGhost("target") then
        ClearTarget()
        TargetNearestEnemy()
    end

    if not UnitCanAttack("player", "target") then
        ClearTarget()
        TargetNearestEnemy()
    end

    for i = 1, 172 do
        if IsAttackAction(i) and not IsCurrentAction(i) then
            Cast("Attack")
            return
        end
    end
end

------------------------------------------------------------
-- MAIN ROTATION
------------------------------------------------------------
local function WarriorDPS_Command()

    WarriorAutoAttackStart()

    -- Charge (only blocked if too close)
    if CanCharge() and not TooCloseForCharge() then
        if not IsInBattleStance() then
            Cast("Battle Stance")
        end
        Cast("Charge")
        return
    end

    -- Execute
    if HasSpell("Execute") and ShouldExecute() and GetRage() > 35 then
        Cast("Execute")
        return
    end

    -- Battle Shout
    if HasSpell("Battle Shout") and not HasBattleShout() and GetRage() >= 10 then
        Cast("Battle Shout")
        return
    end

    -- Bloodthirst
    if HasSpell("Bloodthirst") then
        Cast("Bloodthirst")
        return
    end

    -- Whirlwind (only in melee range)
    if HasSpell("Whirlwind") and InMeleeRange() then
        Cast("Whirlwind")
        return
    end

    -- Heroic Strike
    if HasSpell("Heroic Strike") and GetRage() > 15 then
        Cast("Heroic Strike")
        return
    end
end

------------------------------------------------------------
-- Slash command
------------------------------------------------------------
SLASH_WARRIORDPS1 = "/WarriorDPS"

SlashCmdList["WARRIORDPS"] = function()
    WarriorDPS_Command()
end

------------------------------------------------------------
-- Reset spell cache when learning new spells
------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("LEARNED_SPELL_IN_TAB")
f:SetScript("OnEvent", ResetSpellCache)
