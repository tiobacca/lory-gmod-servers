print("Loading sv_commands.lua")

-- returns a table of players with name matching nick
local function FindPlayersByName(nick)
    if not nick then return {} end
    if nick == "*" then return player.GetAll() end
    if nick == "^" then return {} end
    local foundplayers = {}

    for _, ply in ipairs(player.GetAll()) do
        if string.find(string.lower(ply:Nick()), string.lower(nick)) then
            table.insert(foundplayers, ply)
        end
    end

    return foundplayers
end

-- accounts for when ply = console (legacy)
local function AdminAccess(ply)
    --if true then return true end
    if IsValid(ply) then
        --local access = DR.Ranks[ply:GetUserGroup()] or 1
        return ply:IsSuperAdmin()
    else
        return true
    end
end

-- legacy
function DR:GeneralAdminAccess(ply)
    return AdminAccess(ply)
end

local function DeathrunSafeChatPrint(ply, msg)
    if IsValid(ply) then
        ply:DeathrunChatPrint(msg)
    else
        MsgC(DR.Colors.Turq, msg .. "\n")
    end
end

function DR:SafeChatPrint(ply, msg)
    DeathrunSafeChatPrint(ply, msg)
end

--console commands
concommand.Add("deathrun_respawn", function(ply, cmd, args)
    if args[1] then
        local targets = FindPlayersByName(args[1])

        if DR:CanAccessCommand(ply, cmd) then
            local players = ""

            if #targets > 0 then
                -- for k, targ in ipairs( targets ) do
                -- 	--if ( ply:Team() == TEAM_SPECTATOR ) then
                -- 		--table.remove( targets, k )
                -- 	--end
                -- end
                for k, targ in ipairs(targets) do
                    targ:KillSilent()
                    targ:Spawn()
                    players = players .. targ:Nick() .. ", "
                end
            end

            DeathrunSafeChatPrint(ply, "Respawned " .. string.sub(players, 1, -3) .. ".")
        else
            DeathrunSafeChatPrint(ply, "You are not allowed to do that.")
        end
    elseif not args[1] then
        if (DR:CanAccessCommand(ply, cmd) or ROUND:GetCurrent() == ROUND_WAITING) and (ply:Team() ~= TEAM_SPECTATOR) then
            ply:KillSilent()
            ply:Spawn()
            DeathrunSafeChatPrint(ply, "Respawned yourself.")
        else
            DeathrunSafeChatPrint(ply, "You can't do that right now.")
        end
    else
        DeathrunSafeChatPrint(ply, "Could not execute command.")
    end
end, nil, nil, FCVAR_SERVER_CAN_EXECUTE)

concommand.Add("deathrun_cleanup", function(ply, cmd, args)
    if DR:CanAccessCommand(ply, cmd) or ROUND:GetCurrent() == ROUND_WAITING then
        game.CleanUpMap()
        DeathrunSafeChatPrint(ply, "Cleaned up the map and reset entities.")
    else
        DeathrunSafeChatPrint(ply, "You are not allowed to do that.")
    end
end, nil, nil, FCVAR_SERVER_CAN_EXECUTE)

concommand.Add("deathrun_get_stats", function(ply, cmd, args)
    if args[1] then
        local targets = FindPlayersByName(args[1])

        if #targets == 1 then
            net.Start("deathrun_send_stats")
            --net.WriteString( targets[1]:SteamID() )
            net.WriteTable(sql.Query("SELECT * FROM deathrun_stats WHERE sid = '" .. targets[1]:SteamID() .. "'"))
            net.Send(ply)
        elseif #targets > 1 then
            DeathrunSafeChatPrint(ply, "One player at a time, please.")
        else
            DeathrunSafeChatPrint(ply, "No targets found with that name.")
        end
    elseif not args[1] then
        --print('meme')
        net.Start("deathrun_send_stats")
        --net.WriteString( ply:SteamID() )
        net.WriteTable(sql.Query("SELECT * FROM deathrun_stats WHERE sid = '" .. ply:SteamID() .. "'"))
        net.Send(ply)
    else
        DeathrunSafeChatPrint(ply, "Could not execute command.")
    end
end)

-- chat commands
DR.ChatCommands = {}

function DR:GetChatCommandTable()
    return DR.ChatCommands
end

function DR:AddChatCommand(cmd, func)
    DR.ChatCommands[cmd] = func
    print("Deathrun - Added chat command " .. cmd)
end

function DR:AddChatCommandAlias(cmd, cmd2)
    DR.ChatCommands[cmd2] = DR.ChatCommands[cmd]
    print("Deathrun - Added chat command alias " .. cmd .. " -> " .. cmd2)
end

local function ProcessChat(ply, text, public)
    local args = string.Split(text, " ")
    local prefix = string.sub(args[1], 1, 1)
    local cmd = string.sub(args[1], 2, -1)

    if ((prefix == "!") or (prefix == "/")) and DR.ChatCommands[cmd] then
        local cmdfunc = DR.ChatCommands[cmd]
        local args2 = {}

        for i = 2, #args do
            args2[i - 1] = args[i]
        end

        cmdfunc(ply, args2)
        if prefix == "/" then return false end -- make it silent if you use /
    end
end

hook.Add("PlayerSay", "ProcessDeathrunChat", ProcessChat)

DR:AddChatCommand("respawn", function(ply, args)
    ply:ConCommand("deathrun_respawn " .. (args[1] or ""))
    PrintTable(args)
end)

DR:AddChatCommandAlias("respawn", "r")

DR:AddChatCommand("cleanup", function(ply)
    ply:ConCommand("deathrun_cleanup")
end)

DR:AddChatCommand("help", function(ply)
    ply:ConCommand("deathrun_open_help")
end)

DR:AddChatCommand("settings", function(ply)
    ply:ConCommand("deathrun_open_settings")
end)

DR:AddChatCommand("zones", function(ply)
    ply:ConCommand("deathrun_open_zone_editor")
end)

DR:AddChatCommand("1p", function(ply)
    ply:ConCommand("deathrun_thirdperson_enabled 0")
end)

DR:AddChatCommand("3p", function(ply)
    ply:ConCommand("deathrun_thirdperson_enabled 1")
end)

DR:AddChatCommand("thirdperson", function(ply)
    ply:ConCommand("deathrun_toggle_thirdperson")
end)

DR:AddChatCommand("stats", function(ply, args)
    ply:ConCommand("deathrun_get_stats " .. (args[1] or ""))
end)

DR:AddChatCommand("firstperson", function(ply)
    ply:ConCommand("deathrun_toggle_thirdperson")
end)

DR:AddChatCommand("spec", function(ply, args)
    --if args[1] == "!spec" then
    if ply:ShouldStaySpectating() then
        ply:ConCommand("deathrun_spectate_only 0")
    else
        ply:ConCommand("deathrun_spectate_only 1")
    end
end)

concommand.Add("deathrun_punish", function(ply, cmd, args)
    if args[1] then
        args[2] = args[2] or 1

        if DR:CanAccessCommand(ply, cmd) then
            local targets = FindPlayersByName(args[1])

            if #targets == 0 then
                ply:DeathrunSafeChatPrint("No targets to punish.")
            elseif #targets == 1 then
                local t = targets[1]
                DR:PunishDeathAvoid(t, tonumber(args[2]))
                DeathrunSafeChatPrint(ply, "Punishing " .. tostring(t:Nick()) .. " for another " .. tostring(DR:GetDeathAvoid(t)) .. " rounds.")
            elseif #targets > 1 then
                ply:DeathrunSafeChatPrint("Too many targets to punish.")
            end
        end
    end
end)

DR:AddChatCommand("punish", function(ply, args)
    if not args[1] then return end
    args[2] = args[2] or 1
    ply:ConCommand("deathrun_punish " .. args[1] .. " " .. args[2])
end)