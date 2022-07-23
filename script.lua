local HttpService = game:GetService("HttpService")

local SongMetadata = require(workspace.Songs.SongMetadata)

-- local Knit = require(game.ReplicatedStorage.Packages.Knit)

-- local SongDatabase = require(game.ReplicatedStorage.RobeatsGameCore.SongDatabase)
-- local ScoreManager = require(game.ReplicatedStorage.RobeatsGameCore.ScoreManager)
local AudioManager = require(game.ReplicatedStorage.RobeatsGameCore.AudioManager)

local UI = loadstring(game:HttpGet("https://pastebin.com/raw/eKwyeQa0", true))()

local tab = UI:CreateTab("RoBeats CS+")

-- local oldConstructor = ScoreManager.new

-- local client

-- local function connect()
--     return pcall(function()
--         client = syn.websocket.connect("ws://localhost:8080")
--     end)
-- end

-- connect()

-- local function send(o)
--     pcall(function()
--         client:Send(HttpService:JSONEncode(o))
--     end)
-- end

-- ScoreManager.new = function(...)
--     local sm = oldConstructor(...)
    
--     local oldreg = sm.register_hit
    
--     send({
--         type = "updateScore",
--         score = 0,
--         marvelous = 0,
--         perfect = 0,
--         great = 0,
--         good = 0,
--         bad = 0,
--         miss = 0,
--         maxCombo = 0
--     })
    
--     sm.register_hit = function(self, ...)
--         local ret = oldreg(self, ...)
        
--         local scoreData = debug.getupvalues(sm.get_end_records)
        
--         send({
--             type = "updateScore",
--             score = scoreData[1],
--             marvelous = scoreData[2],
--             perfect = scoreData[3],
--             great = scoreData[4],
--             good = scoreData[5],
--             bad = scoreData[6],
--             miss = scoreData[7],
--             maxCombo = scoreData[8],
--             accuracy = sm:get_accuracy(),
--             mean = sm:get_mean()
--         })
       
--       return ret 
--     end
    
--     return sm
-- end

-- local store = Knit.GetController("StateController").Store

-- local lastSongKey = store:getState().options.transient.SongKey

-- store.changed:connect(function(state)
--     local songKey = state.options.transient.SongKey
    
--     if lastSongKey ~= songKey then
--         lastSongKey = songKey
        
--         send({
--             type = "updateSong",
--             title = SongDatabase:get_artist_for_key(songKey),
--             artist = SongDatabase:get_title_for_key(songKey)
--         })
--     end
-- end)

-- local sound = Instance.new("Sound")
-- sound.SoundId = getsynasset("crescent/bgm_s2ep1.mp3")
-- sound.Parent = game.SoundService

-- sound:Play()

local songs = {}

local function parseOsuFile(path)
    local file = string.split(readfile(path), "\n")
    
    local lastCategory
    
    local ret = {}
    
    for i, line in ipairs(file) do
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

local function addFolder(path)
    local files = listfiles(path)
    
    for _, file in ipairs(files) do
        if string.find(file, ".osu") and not table.find(songs, file) then
            table.insert(songs, file)

            local success, mapData = pcall(parseOsuFile, file)

            if not success then
                warn(mapData)

                table.remove(songs, table.find(songs, file))
            else
                local hitObjects = {}
            
                for i, hitObject in ipairs(mapData.HitObjects) do
                    local obj = {
                        Time = hitObject.Time,
                        Track = math.floor(hitObject.X * 4 / 512) + 1,
                        Type = 1
                    }
                    
                    if hitObject.EndTime ~= 0 then
                        obj.Duration = hitObject.EndTime - hitObject.Time
                        obj.Type = 2
                    end
                    
                    hitObjects[i] = obj
                end
                
                hitObjects = HttpService:JSONEncode(hitObjects)

                local filename

                for _, event in ipairs(mapData.Events) do
                    if event.Type == 0 then
                        filename = event.Filename
                    end
                end

                local toAdd = {
                    AudioFilename = (mapData.Metadata.Title or "Unknown Title") .. " [" .. (mapData.Metadata.Version or "Normal") .. "]",
                    AudioArtist = mapData.Metadata.Artist or "Unknown Artist",
                    AudioMapper = mapData.Metadata.Creator,
                    AudioDifficulty = 0,
                    AudioMod = 0,
                    AudioMD5Hash = syn.crypt.custom.hash("md5", hitObjects),
                    AudioVolume = 0.5,
                    AudioTimeOffset = -70,
                    AudioHitSFXGroup = 0,
                    AudioNotePrebufferTime = 1000,
                    AudioAssetId = getsynasset(path .. "/" .. mapData.General.AudioFilename),
                    SongKey = #SongMetadata + 1
                }

                if filename then
                    toAdd.AudioCoverImageAssetId = getsynasset(path .. "/" .. filename)
                end
                
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
            end
        end
    end
end

local function addAllFolders()
    for _, folder in ipairs(listfiles("robeatscs/songs")) do
        addFolder(folder)
    end
end

UI:MakeButton(tab, "Refresh Songs", addAllFolders)

addAllFolders()