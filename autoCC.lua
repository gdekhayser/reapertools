--[[
    Map Audio Automation to MIDI CC for Each Envelope in Selected Tracks (MIDI items in 'Target' track)
    -----------------------------------------------------------------------------------------------
    This script maps audio automation envelope points from each selected track to MIDI CC events.
    For each envelope in a selected track, it creates a corresponding MIDI CC lane in a MIDI item
    on a track named "Target". Each envelope's points are converted to MIDI CC values (0-127) and
    inserted at the appropriate time positions.

    Functions:
    - getTrackByName(name): Searches for a track by its name and returns the track object if found.
    - mapEnvelopesToCC(): Main function that:
        - Ensures a "Target" track exists (creates one if not).
        - Iterates through selected tracks and their envelopes.
        - For each envelope, creates a MIDI item in the "Target" track.
        - Converts envelope points to MIDI CC events (CC number = envelope index).
        - Inserts MIDI CC events at the corresponding time positions.
        - Sorts MIDI events and updates the arrangement.

    Usage:
    - Select one or more tracks in REAPER.
    - Run the script.
    - The script creates MIDI items in a track named "Target", containing CC data derived from each selected track's automation envelopes.

    Notes:
    - Each envelope is assigned a unique MIDI CC number, starting from the user-specified base.
    - Tracks without envelopes are skipped automatically.
    - All operations are wrapped in REAPER's Undo system for easy reversal.

    @author Your Name
    @version 1.3
--]]
-- @description Map Audio Automation to MIDI CC for Each Envelope in Selected Tracks (MIDI items in 'Target' track)
-- @version 1.3
-- @author Your Name

-- Finds a track by its name and returns the track object if found.
function getTrackByName(name)
    local num_tracks = reaper.CountTracks(0)
    for i = 0, num_tracks - 1 do
        local track = reaper.GetTrack(0, i)
        local retval, track_name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
        if retval and track_name == name then
            return track
        end
    end
    return nil
end

-- Main function to map envelopes to MIDI CC events in the "Target" track.
function mapEnvelopesToCC()
    local cc_target = 16
    local retval, user_input = reaper.GetUserInputs("MIDI CC Mapping", 1, "First CC control number:", "")
    if retval then cc_target = tonumber(user_input) end

    -- Ensure "Target" track exists, create if not.
    local target_track = getTrackByName("Target")
    if not target_track then
        local num_tracks = reaper.CountTracks(0)
        reaper.InsertTrackAtIndex(num_tracks, true)
        target_track = reaper.GetTrack(0, num_tracks)
        reaper.GetSetMediaTrackInfo_String(target_track, "P_NAME", "Target", true)
    end

    -- Check if any tracks are selected.
    local num_sel_tracks = reaper.CountSelectedTracks(0)
    if num_sel_tracks == 0 then
        reaper.ShowMessageBox("No tracks selected.", "Error", 0)
        return
    end

    -- Iterate through selected tracks.
    
    for t = 0, num_sel_tracks - 1 do
        local track = reaper.GetSelectedTrack(0, t)
        local num_env = reaper.CountTrackEnvelopes(track)
        if num_env == 0 then goto continue end

        -- Create a MIDI item in the Target track covering the whole project.
        local item_len = reaper.GetProjectLength()
        local midi_item = reaper.CreateNewMIDIItemInProj(target_track, 0, item_len, false)
        local midi_take = reaper.GetActiveTake(midi_item)
        if not midi_take or not reaper.TakeIsMIDI(midi_take) then
            reaper.ShowMessageBox("Failed to get MIDI take.", "Error", 0)
            goto continue
        end

        -- For each envelope, convert points to MIDI CC events.
        for env_idx = 0, num_env - 1 do
            local envelope = reaper.GetTrackEnvelope(track, env_idx)
            local num_points = reaper.CountEnvelopePoints(envelope)
            if num_points == 0 then goto next_env end

            for pt_idx = 0, num_points - 1 do
                local retval, time, value, _, _, _ = reaper.GetEnvelopePoint(envelope, pt_idx)
                if retval then
                    local midi_cc_value = math.floor(value * 127) -- Scale envelope value to MIDI CC (0-127)
                    local ppq_pos = reaper.MIDI_GetPPQPosFromProjTime(midi_take, time)
                    local cc_num = cc_target + env_name_index -- Use envelope index as CC number (starting from cc_target)
                    reaper.MIDI_InsertCC(midi_take, false, false, ppq_pos, 0xB0, (cc_num - cc_target), cc_num, midi_cc_value)
                end
            end
            ::next_env::
        end

        -- Sort MIDI events for proper playback.
        reaper.MIDI_Sort(midi_take)
        env_name_index = env_name_index + 1 -- Increment for next envelope's CC number
        ::continue::
    end

    -- Update the arrangement view.
    reaper.UpdateArrange()
end

-- Combines all MIDI automation envelopes from selected tracks into a single MIDI item on "Target" track.
function combineMIDIEnvelopesToSingleItem()
    -- Find the "Target" track
    local target_track = getTrackByName("Target")
    if not target_track then
        reaper.ShowMessageBox("No 'Target' track found.", "Error", 0)
        return
    end

    -- Gather all MIDI items on "Target"
    local num_items = reaper.CountTrackMediaItems(target_track)
    if num_items == 0 then
        reaper.ShowMessageBox("No MIDI items found on 'Target' track.", "Error", 0)
        return
    end

    -- Determine combined item length (span all items)
    local min_pos, max_pos = math.huge, 0
    local midi_takes = {}
    for i = 0, num_items - 1 do
        local item = reaper.GetTrackMediaItem(target_track, i)
        local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        min_pos = math.min(min_pos, pos)
        max_pos = math.max(max_pos, pos + len)
        local take = reaper.GetActiveTake(item)
        if take and reaper.TakeIsMIDI(take) then
            table.insert(midi_takes, take)
        end
    end

    -- Create a new MIDI item covering all MIDI items
    local combined_item = reaper.CreateNewMIDIItemInProj(target_track, min_pos, max_pos - min_pos, false)
    local combined_take = reaper.GetActiveTake(combined_item)
    if not combined_take or not reaper.TakeIsMIDI(combined_take) then
        reaper.ShowMessageBox("Failed to create combined MIDI item.", "Error", 0)
        return
    end

    -- Copy all MIDI events from each take into the combined take
    for _, take in ipairs(midi_takes) do
        local _, notes, ccs, sysex = reaper.MIDI_CountEvts(take)
        -- Copy CCs
        for i = 0, ccs - 1 do
            local retval, selected, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, i)
            if retval then
                reaper.MIDI_InsertCC(combined_take, selected, muted, ppqpos, chanmsg, chan, msg2, msg3)
            end
        end
        -- Copy notes
        for i = 0, notes - 1 do
            local retval, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
            if retval then
                reaper.MIDI_InsertNote(combined_take, selected, muted, startppqpos, endppqpos, chan, pitch, vel, false)
            end
        end
        -- Copy sysex
        for i = 0, sysex - 1 do
            local retval, selected, muted, ppqpos, type, msg = reaper.MIDI_GetTextSysexEvt(take, i, false)
            if retval then
                reaper.MIDI_InsertTextSysexEvt(combined_take, selected, muted, ppqpos, type, msg, false)
            end
        end
    end

    -- Sort MIDI events
    reaper.MIDI_Sort(combined_take)

    -- Delete all other MIDI items on "Target" except the new combined one
    for i = num_items, 1, -1 do
        local item = reaper.GetTrackMediaItem(target_track, i - 1)
        if item ~= combined_item then
            reaper.DeleteTrackMediaItem(target_track, item)
        end
    end

    reaper.UpdateArrange()
end

-- Use REAPER's Undo system for safe operation.
env_name_index = 0
reaper.Undo_BeginBlock()
mapEnvelopesToCC()
combineMIDIEnvelopesToSingleItem()
reaper.Undo_EndBlock("Map Audio Automation to MIDI CC for Each Envelope in Selected Tracks", -1)
