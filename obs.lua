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