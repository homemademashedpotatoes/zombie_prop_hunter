--[[
    Zombie Prop Hunter
    Makes npc_zombie target doors/props to break them (works with destructible-door/prop addons).
    Author: ChatGPT
    License: MIT
]]--

if SERVER then
    CreateConVar("zm_target_props", "1", FCVAR_ARCHIVE, "Enable zombies targeting props/doors.")
    CreateConVar("zm_target_props_radius", "900", FCVAR_ARCHIVE, "Search radius for props/doors.")
    CreateConVar("zm_target_props_debug", "0", FCVAR_ARCHIVE, "Debug logging.")

    local TARGET_CLASSES = {
        ["prop_physics"] = true,
        ["prop_physics_multiplayer"] = true,
        ["prop_door_rotating"] = true,
        ["func_door"] = true,
        ["func_door_rotating"] = true,
        ["func_breakable"] = true,
        ["func_physbox"] = true
    }

    local function debugPrint(...)
        if GetConVar("zm_target_props_debug"):GetBool() then
            print("[ZombiePropHunter]", ...)
        end
    end

    local function isValidTarget(ent)
        if (not IsValid(ent)) then return false end
        if ent:IsPlayer() or ent:IsNPC() then return false end  -- we only want world objects, not living actors
        -- Filter by class
        local cls = ent:GetClass()
        if not TARGET_CLASSES[cls] then return false end

        -- Make sure it's not unbreakable world geometry masquerading as a door/prop
        -- If it can take damage or has physics, it's a good candidate.
        if ent:Health() and ent:Health() > 0 then return true end
        if ent:GetInternalVariable and ent:GetInternalVariable("m_iHealth") and ent:GetInternalVariable("m_iHealth") > 0 then return true end

        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then return true end

        -- Some brush doors may not expose health but are still damage-listeners; allow them.
        if cls == "func_door" or cls == "func_door_rotating" then return true end

        return false
    end

    local function hasBetterEnemy(npc)
        local enemy = npc:GetEnemy()
        if not IsValid(enemy) then return false end
        -- If current enemy is a player or NPC and alive, keep it.
        if (enemy:IsPlayer() and enemy:Alive()) or (enemy:IsNPC() and enemy:Health() > 0) then
            return true
        end
        return false
    end

    local function pickNearestTarget(npc, radius)
        local origin = npc:GetPos()
        local nearest, ndist

        for _, ent in ipairs(ents.FindInSphere(origin, radius)) do
            if isValidTarget(ent) and npc:Visible(ent) then
                local d = origin:DistToSqr(ent:GetPos())
                if not ndist or d < ndist then
                    nearest, ndist = ent, d
                end
            end
        end

        return nearest
    end

    -- Staggered thinker to avoid spikes: spread work over time using EntIndex bins.
    local function shouldProcessThisTick(npc, tick)
        -- 5 buckets; roughly process each zombie every ~0.5s with 0.1s timer.
        local bucket = (npc:EntIndex() % 5)
        return (bucket == (tick % 5))
    end

    timer.Create("ZombiePropHunter_Timer", 0.1, 0, function()
        if GetConVar("zm_target_props"):GetBool() == false then return end

        local radius = math.max(128, GetConVar("zm_target_props_radius"):GetInt())
        local tick = CurTime() * 10 -- coarse bucket index

        for _, npc in ipairs(ents.FindByClass("npc_zombie")) do
            if IsValid(npc) and npc:Health() > 0 and shouldProcessThisTick(npc, math.floor(tick)) then
                -- If zombie already has a real enemy (player/NPC), don't override.
                if hasBetterEnemy(npc) then goto CONTINUE end

                local target = pickNearestTarget(npc, radius)
                if IsValid(target) then
                    -- Make it hostile toward the target and chase it.
                    npc:AddEntityRelationship(target, D_HT, 99)
                    npc:SetEnemy(target)
                    npc:UpdateEnemyMemory(target, target:GetPos())

                    -- If very close, try to trigger attack; else chase.
                    local dist = npc:GetPos():DistToSqr(target:GetPos())
                    if dist < (75 * 75) then
                        npc:SetSchedule(SCHED_MELEE_ATTACK1)
                    else
                        npc:SetSchedule(SCHED_CHASE_ENEMY)
                    end

                    debugPrint(string.format("Zombie %d targeting %s [%s]", npc:EntIndex(), tostring(target), target:GetClass()))
                else
                    -- No target found; clear non-living enemies to allow fresh search later.
                    local cur = npc:GetEnemy()
                    if IsValid(cur) and (not cur:IsPlayer()) and (not cur:IsNPC()) then
                        npc:SetEnemy(nil)
                    end
                end
            end
            ::CONTINUE::
        end
    end)

    -- When new zombies spawn, give them basic capabilities (should already exist, but be safe).
    hook.Add("OnEntityCreated", "ZombiePropHunter_Init", function(ent)
        if not IsValid(ent) then return end
        if ent:GetClass() == "npc_zombie" then
            timer.Simple(0, function()
                if not IsValid(ent) then return end
                -- Ensure they can move and attack; typically default, but mods can change capabilities.
                if ent:CapabilitiesGet() == 0 then
                    -- Bits from ai_basenpc: move ground (1), door usage (2048) not needed, melee (128)
                    -- We avoid force-enabling door usage; we want hits instead.
                    local bits = bit.bor(CAP_MOVE_GROUND or 1, CAP_INNATE_MELEE_ATTACK1 or 128)
                    ent:CapabilitiesAdd(bits)
                end
            end)
        end
    end)
end
