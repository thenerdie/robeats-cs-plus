local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local SongMetadata = require(workspace.Songs.SongMetadata)

-- local Knit = require(game.ReplicatedStorage.Packages.Knit)

-- local SongDatabase = require(game.ReplicatedStorage.RobeatsGameCore.SongDatabase)
-- local ScoreManager = require(game.ReplicatedStorage.RobeatsGameCore.ScoreManager)
local AudioManager = require(game.ReplicatedStorage.RobeatsGameCore.AudioManager)

local UI = loadstring(game:HttpGet("https://pastebin.com/raw/eKwyeQa0", true))()

local rcsdir = "robeatscs"
local songsdir = rcsdir .. "/songs"
local cachedir = rcsdir .. "/_difficultycache.txt"

local function decrypt(...)
    if syn then
        return syn.crypt.decrypt(...)
    end

    return base64_decode(...)
end

local function encrypt(...)
    if syn then
        return syn.crypt.encrypt(...)
    end

    return base64_encode(...)
end

local function md5hash(input)
    if syn then
        return syn.crypt.custom.hash("md5", input)
    end

    return crypt_hash(input, "")
end

local function httpRequest(options)
    if syn then
        return syn.request(options)
    end

    return request(options)
end

local function getAsset(url)
    if syn then
        return getsynasset(url)
    end

    return getcustomasset(url)
end

if not isfolder(rcsdir) then
    makefolder(rcsdir)
end

if not isfolder(songsdir) then
    makefolder(songsdir)
end

if not isfile(cachedir) then
    writefile(cachedir, "")
end

local rcsDifficulties = {}

local oldPrint = print

local function print(...)
    local args = {...}

    local str = ""

    for _, v in ipairs(args) do
        str = str .. tostring(v) .. "\t"
    end

    oldPrint("[RCS+] " .. str)
end

local tab = UI:CreateTab("RoBeats CS+")

local info

local waitFrame = true

local userId = game.Players.LocalPlayer.UserId

local function refreshDifficultyCache()
    local success, currentCache = pcall(function()
        local data = decrypt(readfile(cachedir), tostring(userId))

        return HttpService:JSONDecode(data)
    end)

    if success then
        rcsDifficulties = currentCache
    end
end

local function saveDifficultyCache()
    writefile(cachedir, encrypt(HttpService:JSONEncode(rcsDifficulties), tostring(userId)))
end

local function msdToRcs(msd)
    return msd * 1.8
end

local function serializeHitObjects(hitObjects)
    local out = ""

    for _, hitObject in ipairs(hitObjects) do
        out = out .. hitObject.Time .. hitObject.Type .. (hitObject.Duration or "")
    end

    return out
end

local function parseOsuFile(path)
    local file = string.split(readfile(path), "\n")
    
    local lastCategory
    
    local ret = {}
    
    for _, line in ipairs(file) do
        if line ~= "" and not string.find(line, "^//") then
            local key, value = string.match(line, "(.+)%:[%s]?([^%c]+)")
            local category = string.match(line, "%[(.+)%]")
            
            if category and not key and not value then
                ret[category] = {}
                lastCategory = category
            else
                if lastCategory ~= "Events" and lastCategory ~= "TimingPoints" and lastCategory ~= "HitObjects" then
                    if key and value then
                        ret[lastCategory][key] = value
                    end
                elseif lastCategory == "TimingPoints" then
                    local timingPoint = string.split(line, ",")
                    
                    ret[lastCategory] = {
                        Time = tonumber(timingPoint[1]),
                        BeatLength = tonumber(timingPoint[2]),
                        Meter = tonumber(timingPoint[3]),
                        SampleSet = tonumber(timingPoint[4]),
                        SampleIndex = tonumber(timingPoint[5]),
                        Volume = tonumber(timingPoint[6]),
                        Uninherited = tonumber(timingPoint[7]),
                        Effects = tonumber(timingPoint[8])
                    }
                elseif lastCategory == "HitObjects" then
                    local hitObject = string.split(line, ",")
                    
                    table.insert(ret[lastCategory], {
                        X = tonumber(hitObject[1]),
                        Y = tonumber(hitObject[2]),
                        Time = tonumber(hitObject[3]),
                        Type = tonumber(hitObject[4]),
                        HitSound = tonumber(hitObject[5]),
                        EndTime = tonumber(string.split(hitObject[6], ":")[1])
                    })
                elseif lastCategory == "Events" then
                    local event = string.split(line, ",")

                    table.insert(ret[lastCategory], {
                        Type = tonumber(event[1]),
                        Time = tonumber(event[2]),
                        Filename = event[3] and string.sub(event[3], 2, -2) or nil,
                        XOffset = tonumber(event[4]),
                        YOffset = tonumber(event[5])
                    })
                end
            end
        end
    end
    
    return ret
end

local function getMockDifficulties()
    local ret = {}

    for i = 7, 20 do
        table.insert(ret, {
            Overall = 0,
            Chordjack = 0,
            Handstream = 0,
            Jack = 0,
            Jumpstream = 0,
            Stamina = 0,
            Stream = 0,
            Technical = 0,
            Rate = i * 10,
        })
    end

    return ret
end

local function getDifficultyForMap(hitObjects, md5Hash)
    local difficulties = rcsDifficulties[md5Hash]

    if difficulties and #difficulties >= 14 then
        return difficulties
    end

    local success, difficulties = pcall(function()
        local msdDifficulties = httpRequest({
            Url = "http://161.35.49.68/api/difficulties",
            Method = "POST",
            Body = HttpService:JSONEncode({
                HitObjects = hitObjects
            }),
            Headers = {
                ["Content-Type"] = "application/json"
            },
        })
    
        local body = HttpService:JSONDecode(msdDifficulties.Body)
    
        local difficulties = {}
    
        for _, difficulty in ipairs(body) do
            table.insert(difficulties, {
                Overall = msdToRcs(difficulty.Overall),
                Chordjack = msdToRcs(difficulty.Chordjack),
                Handstream = msdToRcs(difficulty.Handstream),
                Jack = msdToRcs(difficulty.Jack),
                Jumpstream = msdToRcs(difficulty.Jumpstream),
                Stamina = msdToRcs(difficulty.Stamina),
                Stream = msdToRcs(difficulty.Stream),
                Technical = msdToRcs(difficulty.Technical),
                Rate = difficulty.Rate,
            })
        end
        
        return difficulties
    end)

    local mapDifficulties

    if success and difficulties and #difficulties >= 14 then
        mapDifficulties = difficulties
    else
        mapDifficulties = getMockDifficulties()
    end

    return mapDifficulties
end

local found = {}

local function addFolder(path)
    local files = listfiles(path)
    
    for _, file in ipairs(files) do
        if string.find(file, "^(.+).osu$") and not table.find(found, file) then
            table.insert(found, file)

            local success, mapData = pcall(parseOsuFile, file)

            if not success then
                warn(mapData)

                table.remove(found, table.find(found, file))
            else
                local hitObjects = {}
            
                local skip = false

                if mapData.Difficulty.CircleSize ~= "4" or mapData.General.Mode ~= "3" then
                    skip = true
                end

                for i, hitObject in ipairs(mapData.HitObjects) do
                    local obj = {
                        Time = hitObject.Time,
                        Track = math.floor(hitObject.X * 4 / 512) + 1,
                        Type = 1
                    }

                    if obj.Track > 4 or not hitObject.EndTime then
                        skip = true
                        break
                    end
                    
                    local duration = hitObject.EndTime - hitObject.Time

                    if hitObject.EndTime ~= 0 and duration > 0 then
                        obj.Duration = duration
                        obj.Type = 2
                    end
                    
                    hitObjects[i] = obj
                end

                if skip then
                    print("Skipping " .. file .. "...")
                    continue
                end
                
                local filename
                
                for _, event in ipairs(mapData.Events) do
                    if event.Type == 0 then
                        filename = event.Filename
                    end
                end

                local md5Hash = md5hash(serializeHitObjects(hitObjects))

                local toAdd = {
                    AudioFilename = (mapData.Metadata.Title or "Unknown Title") .. " [" .. (mapData.Metadata.Version or "Normal") .. "]",
                    AudioArtist = mapData.Metadata.Artist or "Unknown Artist",
                    AudioMapper = mapData.Metadata.Creator,
                    AudioDifficulty = getDifficultyForMap(hitObjects, md5Hash),
                    AudioMod = 0,
                    AudioMD5Hash = md5Hash,
                    AudioVolume = 0.5,
                    AudioTimeOffset = -70,
                    AudioHitSFXGroup = 0,
                    AudioNotePrebufferTime = 1000,
                    AudioAssetId = getAsset(path .. "/" .. mapData.General.AudioFilename),
                    SongKey = #SongMetadata + 1,
                    AudioCustom = true,
                }
                
                if filename then
                    toAdd.AudioCoverImageAssetId = getAsset(path .. "/" .. filename)
                end

                hitObjects = HttpService:JSONEncode(hitObjects)
                
                local MAX_CHARACTERS_PER_OBJ = 2e5 - 1
                
                local numberOfSplits = math.ceil(#hitObjects / MAX_CHARACTERS_PER_OBJ)
                
                local splits = {}
                
                for i = 1, numberOfSplits do
                    splits[i] = string.sub(hitObjects, MAX_CHARACTERS_PER_OBJ*(i-1)+1, math.clamp(MAX_CHARACTERS_PER_OBJ*i, 0, #hitObjects))
                end
                
                local mapDataFolder = Instance.new("Folder")
                mapDataFolder.Name = mapData.Metadata.Title or "Unknown"
        
                for i, split in ipairs(splits) do
                    local mapDataValueObject = Instance.new("StringValue")
                    mapDataValueObject.Name = string.format("%d", i)
                    mapDataValueObject.Value = split
                    
                    mapDataValueObject.Parent = mapDataFolder
                end
                
                toAdd.AudioMapData = mapDataFolder
                
                mapDataFolder.Parent = workspace.Songs.SongMaps
                
                table.insert(SongMetadata, toAdd)

                print("Added " .. file .. "!")
            end
            
            if waitFrame then
                RunService.Heartbeat:Wait()
            end
        end
    end
end

local function addAllFolders()
    refreshDifficultyCache()

    local folders = listfiles(songsdir)

    for i, folder in ipairs(folders) do
        info.Text = string.format("Loading %d/%d", i, #folders)

        addFolder(folder)

        if i % 25 == 0 then
            saveDifficultyCache()
        end
    end

    info.Text = "Ready!"

    saveDifficultyCache()
end

UI:MakeButton(tab, "Refresh Songs", addAllFolders)
info = UI:MakeLabel(tab, "Refreshing songs...")

info.TextScaled = true
info.TextXAlignment = Enum.TextXAlignment.Left

UI:MakeToggle(tab, "Defer Loading", waitFrame, function()
    waitFrame = not waitFrame
end)

addAllFolders()