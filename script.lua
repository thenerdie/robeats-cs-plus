local HttpService = game:GetService("HttpService")

local SongMetadata = require(workspace.Songs.SongMetadata)

-- local Knit = require(game.ReplicatedStorage.Packages.Knit)

-- local SongDatabase = require(game.ReplicatedStorage.RobeatsGameCore.SongDatabase)
-- local ScoreManager = require(game.ReplicatedStorage.RobeatsGameCore.ScoreManager)
local AudioManager = require(game.ReplicatedStorage.RobeatsGameCore.AudioManager)

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

local oldAudioManager = AudioManager.new

AudioManager.new = function(...)
    local am = oldAudioManager(...)
    
    local oldload = am.load_song
    
    am.load_song = function(self, songKey, config)
        print("Loading song...")
        
        oldload(self, songKey, config, function(bgm, audioData)
            local asset = string.match(audioData.AudioAssetId, "file://(.+)")
            
            if asset then
                bgm.SoundId = getsynasset(asset)
                return
            end
            
            bgm.SoundId = audioData.AudioAssetId
        end)
    end
    
    return am
end

local function parseOsuFile(path)
    local file = string.split(readfile(path), "\n")
    
    local lastCategory
    
    local ret = {}
    
    for i, line in ipairs(file) do
        if line ~= "" then
            local category = string.match(line, "%[(.+)%][%s+?]")
            
            if category then
                ret[category] = {}
                lastCategory = category
            else
                if lastCategory ~= "Events" and lastCategory ~= "TimingPoints" and lastCategory ~= "HitObjects" then
                    local key, value = string.match(line, "(.+)%:[%s]?([^%c]+)")
                    
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
                end
            end
        end
    end
    
    return ret
end

local function addFolder(path)
    local files = listfiles(path)
    
    for _, file in ipairs(files) do
        if string.find(file, ".osu") then
            local mapData = parseOsuFile(file)
            
            local toAdd = {
                AudioFilename = mapData.Metadata.Title .. " [" .. (mapData.Metadata.Version or "Normal") .. "]",
                AudioArtist = mapData.Metadata.Artist,
                AudioDifficulty = 0,
                AudioMod = 0,
                AudioMD5Hash = "",
                AudioVolume = 0.5,
                AudioTimeOffset = -70,
                AudioHitSFXGroup = 0,
                AudioNotePrebufferTime = 1000,
                AudioAssetId = "file://" .. path .. "/" .. mapData.General.AudioFilename,
                SongKey = #SongMetadata + 1
            }
            
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
            
            local MAX_CHARACTERS_PER_OBJ = 2e5 - 1
            
            local numberOfSplits = math.ceil(#hitObjects / MAX_CHARACTERS_PER_OBJ)
        
            local splits = {}
    
            for i = 1, numberOfSplits do
                splits[i] = string.sub(hitObjects, MAX_CHARACTERS_PER_OBJ*(i-1)+1, math.clamp(MAX_CHARACTERS_PER_OBJ*i, 0, #hitObjects))
            end
    
            local mapDataFolder = Instance.new("Folder")
            mapDataFolder.Name = mapData.Metadata.Title
    
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

for _, folder in ipairs(listfiles("robeatscs/songs")) do
    addFolder(folder)
end