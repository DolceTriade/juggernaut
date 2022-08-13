-- Globals
juggernaut = nil
oldOrigin = nil
teleport = nil
gameOver = false
KILLS_REQ = 10
KILLS = {}

function Say(ent, txt)
    local num = -1
    if ent ~= nil then
        num = ent.number
    end
    sgame.SendServerCommand(num, 'print ' .. '"' .. txt .. '"')
end

function CP(ent, txt)
    local num = -1
    if ent ~= nil then
        num = ent.number
    end
    sgame.SendServerCommand(num, 'cp ' .. '"' .. txt .. '"')
end

function Putteam(ent, team)
    if ent == nil or ent.client == nil then
        return
    end
    Cmd.exec('delay 1f putteam ' .. ent.number .. ' ' .. team)
end

function Spawn(ent, team)
    if ent == nil or ent.client == nil then
        return
    end
    Cmd.exec('delay 1f putteam ' .. ent.number .. ' ' .. team)
end

function PrintHelp(ent, args)
    Say(ent, [=[Welcome to the Juggernaut mod!
Kill the Juggernaut (the alien) to become the alien.
First alien with 10 kills wins the game!
List of commands: !help !kills']=])
end

function PrintKills(ent, args)
    local out = "Kills:\n"
    for k,v in pairs(KILLS) do
        out = out .. sgame.entity[k].client.name .. "^* = " .. v .. "\n"
    end
    Say(ent, out)
end

COMMANDS = {
    ["help"]=PrintHelp,
    ["kills"]=PrintKills,
}

function SameEnt(a, b)
    if a == nil or b == nil then
        return false
    end
    return a.number == b.number
end

function ParseArgs(m)
    local args = {}
    local idx
    local oldIdx = 1
    while true do
        idx = m:find(' ', oldIdx)
        if idx == nil then
            table.insert(args, m:sub(oldIdx))
            return args
        end
        table.insert(args, m:sub(oldIdx, idx))
        oldIdx = idx
    end
end

function ExecChatCommand(ent, team, message)
    if message:sub(1, 1) == '!' then
        local idx = message:find(' ')
        local c = message:sub(2)
        if idx ~= nil then
            c = message:sub(2, idx)
        end
        local cmd = COMMANDS[c]
        if cmd ~= nil then
            cmd(ent, ParseArgs(message))
        end
    end
end

function WelcomeClient(ent, connect)
    CP(ent, 'Welcome to the Juggernaut mod! Type !help for more info.')
end

function SetJuggernaut(ent)
    juggernaut = ent
    Putteam(ent, 'a')
    if not KILLS[ent.number] then
        KILLS[ent.number] = 0
    end
    CP(nil, ent.client.name .. ' is now the juggernaut!')
end

function PickJug(ent, team)
    if juggernaut == nil then
        if team == "human" then
            SetJuggernaut(ent)
        end
    end
end

function MaybeResetJug(ent, connect)
    -- TODO: Make this smarter by picking a player with the largest kill count or something...
    if SameEnt(ent, juggernaut) and not connect then
        local start = math.random(-1, 62)
        local i = start
        while true do
            local e = sgame.entity[i]
            if e ~= nil and e.client ~= nil and e.team == "human" then
                SetJuggernaut(e)
                return
            end
            i = i + 1
            i = i % 64
            if i == start then
                return
            end
        end
        CP(nil, "Unable to set juggeranut!")
    end
end

function JugDie(ent, inflictor, attacker, mod)
    if inflictor ~= nil and inflictor.client ~= nil then
        oldOrigin = ent.origin
        Putteam(juggernaut, 'h')
        SetJuggernaut(inflictor)
    else
        oldOrigin = nil
    end
end

function RestoreHealth()
    local health = juggernaut.client.health
    local max_health = unv.classes[juggernaut.client.class].health
    health = health + max_health * 0.25
    if health > max_health then
        health = max_health
    end
    juggernaut.client.health = health
end

function KillCount(ent, inflictor, attacker, mod)
    if SameEnt(inflictor, juggernaut) then
        KILLS[juggernaut.number] = KILLS[juggernaut.number] + 1
        CP(nil, 'Juggernaut has ' .. KILLS[juggernaut.number] .. ' kills!')
        RestoreHealth()
        if KILLS[juggernaut.number] == KILLS_REQ then
            gameOver = true
        end
    end
end

function Accounting(ent)
    if SameEnt(ent, juggernaut) then
        ent.die = JugDie
        if ent.client.health > 0 and oldOrigin ~= nil then
            teleport = oldOrigin
            teleport[3] = teleport[3] + 50
            oldOrigin = nil
            Timer.add(100, function() ent.client:teleport(teleport); teleport = nil; end)
        end
        return
    end
    ent.die = KillCount
end

function GameEnd()
    if gameOver then
        return 'aliens'
    end
    return false
end

function init()
    sgame.hooks.RegisterChatHook(ExecChatCommand)
    sgame.hooks.RegisterClientConnectHook(WelcomeClient)
    sgame.hooks.RegisterClientConnectHook(MaybeResetJug)
    sgame.hooks.RegisterTeamChangeHook(PickJug)
    sgame.hooks.RegisterPlayerSpawnHook(Accounting)
    sgame.hooks.RegisterGameEndHook(GameEnd)
    Cmd.exec('lock a')
    print('Loaded lua...')

end

init()
