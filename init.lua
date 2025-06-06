local player_warnings = {}
local saved_chatlogs = "" 

minetest.register_chatcommand("warn", {
    description = "Warns a player with a reason (requires 'staff' privilege)",
    params = "<player> <reason>",
    privs = { staff = true },
    func = function(name, param)
        local player_name, reason = param:match("^(%S+)%s+(.+)$")
        if player_name and reason then
            if not player_warnings[player_name] then
                player_warnings[player_name] = { count = 0, reasons = {} }
            end
            player_warnings[player_name].count = player_warnings[player_name].count + 1
            table.insert(player_warnings[player_name].reasons, reason)
            minetest.chat_send_player(player_name, core.colorize("#ff0000", "[XUtilities-WARNINGS] You have been warned for: " .. reason))
            minetest.chat_send_player(name, core.colorize("#64ff00", "[XUtilities-WARNINGS] You warned " .. player_name .. " with the reason: " .. reason))
            if player_warnings[player_name].count >= 3 then
                local warning_message = "[XUtilities-WARNINGS] You have been kicked after 3 warnings. The reasons are:"
                for i, r in ipairs(player_warnings[player_name].reasons) do
                    warning_message = warning_message .. "\n" .. i .. ". " .. r
                end
                minetest.chat_send_player(player_name, core.colorize("#ff0000", warning_message))
                minetest.kick_player(player_name, "[XUtilities-WARNINGS] You have been kicked for receiving 3 warnings.")
                player_warnings[player_name] = nil
            else
                minetest.chat_send_player(player_name, core.colorize("#ff0000", "[XUtilities-WARNINGS] You now have " .. player_warnings[player_name].count .. " warnings."))
            end
        else
            minetest.chat_send_player(name, "Usage: /warn <player> <reason>")
        end
    end,
})

minetest.register_privilege("staff", {
    description = "Staff privilege for XUtilities mod commands.",
    give_to_singleplayer = false,
})

minetest.register_privilege("developer", {
    description = "Developer privilege for accessing and managing server logs.",
    give_to_singleplayer = false,
})

local reports = {}
local report_id_counter = 1

local function save_reports()
    local path = minetest.get_worldpath() .. "/reports.txt"
    local file = io.open(path, "w")
    if file then
        file:write(minetest.serialize(reports))
        file:close()
    end
end

--Patch
local function save_chatlog()
  local path = minetest.get_worldpath() .. "/chatlog.txt"
  local file = io.open(path, "w")
  if file then
    file:write(saved_chatlogs)
    file:close()
  end
end

local function load_reports()
    local path = minetest.get_worldpath() .. "/reports.txt"
    local file = io.open(path, "r")
    if file then
        local content = file:read("*a")
        reports = minetest.deserialize(content) or {}
        file:close()
    end
end

--Patch
local function load_chatlog()
    local path = minetest.get_worldpath() .. "/chatlog.txt"
    local file = io.open(path, "r")
    if file then
        local content = file:read("*a")
        saved_chatlogs = content or ""
        file:close()
    end
end

load_reports()
--Patch
load_chatlog()

minetest.register_on_shutdown(function()
  save_reports()
  save_chatlog()
end)

minetest.register_chatcommand("report", {
    description = "Submit a report against another player (for cheating or rule-breaking)",
    params = "<username> <reason>",
    func = function(name, param)
        local reported_name, reason = param:match("^(%S+)%s+(.+)$")
        if reported_name and reason then
            local reported_player = minetest.get_player_by_name(reported_name)
            if not reported_player then
                minetest.chat_send_player(name, core.colorize("#ff0000", "[XUtilities-REPORT] The player " .. reported_name .. " is not online."))
                return
            end
            local reported_uuid = reported_player:get_player_name()
            local report_id = report_id_counter
            reports[report_id] = {
                reporter_name = name,
                reporter_uuid = name,
                reported_name = reported_name,
                reported_uuid = reported_uuid,
                reason = reason,
                claimed_by = nil,
                closed = false,
            }
            report_id_counter = report_id_counter + 1
            minetest.chat_send_player(name, core.colorize("#00ff00", "[XUtilities-REPORT] Your report has been submitted."))
        else
            minetest.chat_send_player(name, core.colorize("#ff0000", "[XUtiltiies-REPORT] Please provide a username and a reason. Usage: /report <username> <reason>"))
        end
    end,
})

local function generate_report_formspec()
    local formspec = "size[8,9]" .. "label[0.5,0.5;Reports]"
    local y_offset = 1.5
    for report_id, report in pairs(reports) do
        if not report.closed then
            local button_label = report.reason
            if report.claimed_by then
                button_label = button_label .. " (Claimed by " .. report.claimed_by .. ")"
            end
            formspec = formspec .. "button[0.5," .. y_offset .. ";7,1;report_" .. report_id .. ";" .. button_label .. "]"
            y_offset = y_offset + 1.5
        end
    end
    return formspec
end

minetest.register_chatcommand("reports", {
    description = "View all submitted reports (requires 'staff' privilege)",
    privs = { staff = true },
    func = function(name)
        if next(reports) == nil then
            minetest.chat_send_player(name, core.colorize("#ff0000", "[XUtilities-REPORT] No reports have been submitted yet."))
        else
            minetest.show_formspec(name, "report_system:reports", generate_report_formspec())
        end
    end,
})

minetest.register_on_player_receive_fields(function(player, formname, fields)
    local pname = player:get_player_name()
    if formname == "report_system:reports" then
        for field, _ in pairs(fields) do
            if field:sub(1, 7) == "report_" then
                local report_id = tonumber(field:sub(8))
                if report_id and reports[report_id] then
                    local report = reports[report_id]
                    local claimed_by = report.claimed_by or "Not claimed"
                    local status = report.closed and "Closed" or "Open"
                    local formspec = "size[8,9]"
                    formspec = formspec .. "label[0.5,0.5;Report ID: " .. report_id .. "]"
                    formspec = formspec .. "label[0.5,1.0;Reporter: " .. report.reporter_name .. "]"
                    formspec = formspec .. "label[0.5,1.5;Reported: " .. report.reported_name .. "]"
                    formspec = formspec .. "label[0.5,2.0;Reason: " .. report.reason .. "]"
                    formspec = formspec .. "label[0.5,2.5;Claimed by: " .. claimed_by .. "]"
                    formspec = formspec .. "label[0.5,3.0;Status: " .. status .. "]"
                    formspec = formspec .. "button[0.5,4.0;3,1;claim_" .. report_id .. ";Claim]"
                    formspec = formspec .. "button[4.5,4.0;3,1;close_" .. report_id .. ";Close]"
                    minetest.show_formspec(pname, "report_system:report_details_" .. report_id, formspec)
                end
            end
        end
    end
    if formname:sub(1,29) == "report_system:report_details_" then
        local report_id = tonumber(formname:sub(30))
        if report_id and reports[report_id] then
            local report = reports[report_id]
            if fields["claim_" .. report_id] then
                report.claimed_by = pname
                minetest.chat_send_player(pname, core.colorize("#00ff00", "[XUtilities-REPORT] You have claimed report " .. report_id))
            end
            if fields["close_" .. report_id] then
                report.closed = true
                minetest.chat_send_player(report.reporter_name, core.colorize("#00ff00", "[XUtilities-REPORTS] Your report " .. report_id .. " has been dealt with."))
                minetest.chat_send_player(pname, core.colorize("#00ff00", "[XUtilities-REPORT] You have closed report " .. report_id))
            end
            minetest.show_formspec(pname, "report_system:reports", generate_report_formspec())
        end
    end
end)

local hud_ids = {}

local function wrap_text(text, limit)
    local lines = {}
    local line = ""
    for word in text:gmatch("%S+") do
        if #line + #word + 1 > limit then
            table.insert(lines, line)
            line = word
        else
            if #line > 0 then
                line = line .. " " .. word
            else
                line = word
            end
        end
    end
    if #line > 0 then
        table.insert(lines, line)
    end
    return table.concat(lines, "\n")
end

minetest.register_chatcommand("announce", {
    description = "Make an announcement (requires 'staff' privilege)",
    params = "<message>",
    privs = { admin = true },
    func = function(name, param)
        local message = param

        if message and message ~= "" then
            local announcement = "-!- ANNOUNCEMENT -!-\n" .. wrap_text(message, 50)

            -- Remove previous announcements
            for _, player in ipairs(minetest.get_connected_players()) do
                local pname = player:get_player_name()
                if hud_ids[pname] then
                    player:hud_remove(hud_ids[pname])
                    hud_ids[pname] = nil
                end
            end

            -- Add new announcement
            for _, player in ipairs(minetest.get_connected_players()) do
                local pname = player:get_player_name()
                hud_ids[pname] = player:hud_add({
                    hud_elem_type = "text",
                    position = {x = 0.5, y = 0.05},
                    offset = {x = 0, y = 0},
                    text = core.colorize("#ff0000", announcement),
                    alignment = {x = 0, y = 0},
                    scale = {x = 100, y = 100},
                    number = 0xFF0000,
                })
            end

            -- Countdown timer
            for i = 1, 10 do
                minetest.after(i, function()
                    for _, player in ipairs(minetest.get_connected_players()) do
                        local pname = player:get_player_name()
                        if hud_ids[pname] then
                            player:hud_change(hud_ids[pname], "text", core.colorize("#ff0000", announcement .. "\nDisappearing in " .. (10 - i) .. " seconds"))
                        end
                    end
                end)
            end

            -- Remove announcement after 10 seconds
            minetest.after(10, function()
                for _, player in ipairs(minetest.get_connected_players()) do
                    local pname = player:get_player_name()
                    if hud_ids[pname] then
                        player:hud_remove(hud_ids[pname])
                        hud_ids[pname] = nil
                    end
                end
            end)
        else
            minetest.chat_send_player(name, core.colorize("#ff0000", "[XUtilities-ANNOUNCE] Please provide a message. Usage: /announce <message>"))
        end
    end,
})

-- Automated Messages
local time_passed = 0  -- Declare it outside the function so it persists.

minetest.register_globalstep(function(dtime)
    time_passed = time_passed + dtime  -- Accumulate time
    if time_passed >= 300 then  -- 5 minutes
        local messages = {
            core.colorize("#ff0000", "[XUtilities] Thank you for playing This Server!"),
            core.colorize("#ff0000", "[XUtilities] See someone breaking a rule? Do /report <username> <reason> to open a report."),
            core.colorize("#ff0000", "[XUtilities] Logs can be easily retrieved, please do not break rules as we can view the logs!"),
        }
        local msg = messages[math.random(#messages)]  -- Select a random message.
        minetest.chat_send_all(msg)
        time_passed = 0  -- Reset the timer
    end
end)

-- Simple terminal mod for Minetest with real-time Lua execution and error handling

local terminal_history = {}  -- Stores terminal command history

-- Function to execute Lua commands safely and capture output
local function execute_command(player_name, command)
    local result = ""
    local success, err = pcall(function()
        -- Capture print output
        local original_print = print
        print = function(...)  -- Override print function to capture output
            result = result .. table.concat({...}, " ") .. "\n"  -- Append output to result
        end

        -- Compile and execute the command
        local func, loadErr = loadstring(command)  -- Compile the command

        if not func then
            result = "Error: " .. loadErr  -- Error compiling command
            return
        end

        -- Execute the command (only runs once)
        func()

        -- Restore the original print function
        print = original_print
    end)

    if not success then
        result = "Error: " .. err
    end

    return result
end

-- Function to show the terminal GUI
local function open_terminal(player_name)
    if not minetest.check_player_privs(player_name, {developer = true}) then
        return
    end

    local formspec = "size[10,8]" ..
                     "textarea[0.5,1;9,6;terminal_output;Terminal Output;]" ..
                     "field[0.5,7;9,1;terminal_input;Input Command;]" ..
                     "button_exit[3.5,7.5;3,1;run;Run]"

    minetest.show_formspec(player_name, "luaterminal:terminal", formspec)
end

-- Handle form submission (command execution)
minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname == "luaterminal:terminal" then
        local player_name = player:get_player_name()

        if fields.terminal_input and fields.terminal_input ~= "" then
            local command = fields.terminal_input
            local output = execute_command(player_name, command)

            -- Show the result in the terminal (clear previous output)
            local formspec = "size[10,8]" ..
                             "textarea[0.5,1;9,6;terminal_output;Terminal Output;" .. minetest.formspec_escape(output) .. "]" ..
                             "field[0.5,7;9,1;terminal_input;Input Command;]" ..
                             "button_exit[3.5,7.5;3,1;run;Run]"

            minetest.show_formspec(player_name, "luaterminal:terminal", formspec)
        end
    end
end)

-- Register chat command to open the terminal
minetest.register_chatcommand("luaterminal", {
    description = "Open the terminal interface for real-time Lua execution (requires luaterminaladmin priv)",
    func = function(name)
        open_terminal(name)
    end,
})

local staff_chat_enabled = {}
local staff_chat_channel = "staff"

local function get_staff_chat_color(player_name)
    if minetest.check_player_privs(player_name, { developer = true }) then
        return "#ff00ff" -- Magenta for developers
    elseif minetest.check_player_privs(player_name, { admin = true }) then
        return "#ff0000" -- Red for admins
    elseif minetest.check_player_privs(player_name, { staff = true }) then
        return "#ffff00" -- Yellow for staff
    end
    return "#ffffff" -- Default white color
end

local function get_staff_chat_role(player_name)
    if minetest.check_player_privs(player_name, { developer = true }) then
        return "Developer"
    elseif minetest.check_player_privs(player_name, { admin = true }) then
        return "Admin"
    elseif minetest.check_player_privs(player_name, { staff = true }) then
        return "Staff"
    end
    return "Guest" -- Default role if none of the privileges are found
end

local function send_staff_chat_message(sender, message)
    local role = get_staff_chat_role(sender)
    local color = get_staff_chat_color(sender)
    local formatted_message = core.colorize(color, "[XUtilities-STAFFCHAT] [" .. role .. "] <" .. sender .. ">: " .. message)
    for _, player in ipairs(minetest.get_connected_players()) do
        local player_name = player:get_player_name()
        if minetest.check_player_privs(player_name, { staff = true }) then
            minetest.chat_send_player(player_name, formatted_message)
        end
    end
end

minetest.register_privilege("admin", {
    description = "Admin privilege",
    give_to_singleplayer = false,
})

minetest.register_chatcommand("sc", {
    description = "Toggle staff chat (requires 'staff' privilege)",
    privs = { staff = true },
    func = function(name, param)
        if staff_chat_enabled[name] then
            staff_chat_enabled[name] = false
            minetest.chat_send_player(name, core.colorize("#ff0000", "[XUtilities-STAFFCHAT] Disabled! Type /sc to enable."))
        else
            staff_chat_enabled[name] = true
            minetest.chat_send_player(name, core.colorize("#64ff00", "[XUtilities-STAFFCHAT] Enabled! Type /sc to disable."))
        end
    end,
})

minetest.register_on_chat_message(function(name, message)
    if staff_chat_enabled[name] then
        send_staff_chat_message(name, message)
        return true -- Prevent the message from being sent to the regular chat
    end
    return false
end)

local log_file = minetest.get_worldpath() .. "/chatlog.txt"

minetest.register_on_chat_message(function(name, message)
    --Patch: We're gonna append the string to include the recent message posted for the chat log instead of writing chat messages to a logfile everytime someone posts something in chat
    saved_chatlogs = saved_chatlogs.."[" .. os.date("%Y-%m-%d %H:%M:%S") .. "] [" .. name .. "] " .. message .. "\n"
end)

local function get_formspec(message_list, search_term)
    local number_of_messages = #message_list
    return table.concat({
        "size[10,10]",
        "label[0,0;" .. "# " .. minetest.colorize(" #FFA756", "XUtilities Chat Logs") .. " | Last " .. number_of_messages .. " messages...]",
        "box[-0.1,-0.1;10,0.7;black]",
        "box[-0.1,0.7;10,8.55;#030303]",
        "textarea[0.2,0.7;10.2,10;;;" .. minetest.formspec_escape(table.concat(message_list, "\n")) .. "]",
        "field[0.2,9.7;3,1;search;;" .. (search_term or "") .. "]",
        "button[2.85,9.34;2,1.1;search_button;Search]"
    })
end

minetest.register_chatcommand("chatlogs", {
    description = "View the chat log (staff only)",
    privs = {staff=true},
    func = function(name)
      -- Split the log content into lines and create the formspec
      local log_lines = string.split(saved_chatlogs, "\n")
      local formspec = get_formspec(log_lines)

      -- Show the formspec to the player
      minetest.show_formspec(name, "erai:chatlogs", formspec)

      return true, "Chat log opened."
    end
})

minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname == "erai:chatlogs" then
        if fields.search_button then
            local search_term = fields.search:lower()
            local file = io.open(log_file, "r")
            if file then
                local log_content = file:read("*all")
                file:close()

                -- Filter the log content based on the search term
                local log_lines = string.split(log_content, "\n")
                local filtered_lines = {}
                for _, line in ipairs(log_lines) do
                    if string.find(line:lower(), search_term) then
                        table.insert(filtered_lines, line)
                    end
                end

                -- Create the formspec with the filtered log content
                local formspec = get_formspec(filtered_lines, search_term)

                -- Show the formspec to the player
                minetest.show_formspec(player:get_player_name(), "erai:chatlogs", formspec)
            end
        end
        return true
    end
    return false
end)

local logs_per_page = 100

-- Function to get the last N lines efficiently
local function read_last_n_lines(file_path, num_lines, search_term)
    local file = io.open(file_path, "r")
    if not file then return nil, "Error: Could not read debug.txt." end

    local lines = {}
    local search_enabled = search_term and search_term ~= ""
    local search_lower = search_enabled and search_term:lower() or nil

    -- Read file in chunks from the end
    local chunk_size = 4096  -- Read last 4KB
    file:seek("end", -chunk_size)
    local data = file:read("*a")
    file:close()

    if not data then return nil, "Error: Could not read log content." end

    -- Convert data into lines
    local all_lines = {}
    for line in data:gmatch("[^\r\n]+") do
        if search_enabled then
            if line:lower():find(search_lower, 1, true) then
                all_lines[#all_lines + 1] = line  -- Proper index insertion
            end
        else
            all_lines[#all_lines + 1] = line
        end
    end

    -- Get the last N lines
    local start_idx = math.max(1, #all_lines - num_lines + 1)
    for i = start_idx, #all_lines do
        lines[#lines + 1] = all_lines[i]:gsub("%d+%.%d+%.%d+%.%d+", "[IP REMOVED]")
    end

    return lines
end

local logs_per_page = 100  -- Number of logs per page

local function read_logs_for_page(page, search_term)
    local path = minetest.get_worldpath() .. "/debug.txt"
    local file, err = io.open(path, "r")
    if not file then
        return nil, err
    end

    local logs = {}
    if search_term == "" then
        local skip = (page - 1) * logs_per_page
        for i = 1, skip do
            if not file:read("*l") then break end
        end
        for i = 1, logs_per_page do
            local line = file:read("*l")
            if not line then break end
            table.insert(logs, line)
        end
        file:close()
        return logs, nil  
    else
        local filtered_logs = {}
        for line in file:lines() do
            if line:lower():find(search_term:lower(), 1, true) then
                table.insert(filtered_logs, line)
            end
        end
        file:close()
        local total = #filtered_logs
        local start_idx = (page - 1) * logs_per_page + 1
        local end_idx = math.min(start_idx + logs_per_page - 1, total)
        for i = start_idx, end_idx do
            table.insert(logs, filtered_logs[i])
        end
        return logs, total
    end
end

minetest.register_chatcommand("logs", {
    description = "View logs efficiently (pages of " .. logs_per_page .. " lines).",
    privs = {developer = true},
    func = function(name, param)
        local search_term, page = param:match("^(.-)%s*(%d*)$")
        search_term = (search_term and search_term:match("^%s*(.-)%s*$") or "")
        page = tonumber(page) or 1

        local logs, total_logs = read_logs_for_page(page, search_term)
        if not logs then
            return false, "Failed to read logs"
        end

        local label_text = minetest.colorize("red", "XUtilities Server Logs")
        if search_term == "" then
            label_text = label_text .. " | Page " .. page
        else
            local max_pages = math.ceil(total_logs / logs_per_page)
            label_text = label_text .. " | Page " .. page .. "/" .. max_pages
        end

        local formspec = table.concat({
            "size[10,10]",
            "label[0,0;" .. label_text .. "]",
            "box[-0.1,-0.1;10,0.7;black]",
            "button[7.5,0.2;1.3,0.3;refresh;Refresh]",
            "button[8.8,0.2;1.2,0.3;clear_button;Clear]",
            "box[-0.1,0.7;10,8.55;#030303]",
            "textarea[0.2,0.7;10.2,10;;;" .. minetest.formspec_escape(table.concat(logs, "\n")) .. "]",
            "field[0,0;0,0;page;;" .. page .. "]",
            "button[2.8,9.34;1.5,1.1;prev_page;<]",
            "button[4.4,9.34;1.8,1.1;search_button;Search]",
            "field[6.3,9.7;2.2,1;search;;" .. minetest.formspec_escape(search_term) .. "]",
            "button[8.5,9.34;1.5,1.1;next_page;>]",
            "button_exit[0,9.34;1.5,1.1;close;Close]"
        }, "")

        minetest.show_formspec(name, "erai:log_viewer", formspec)
        return true, "Logs loaded successfully."
    end
})

minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname == "erai:log_viewer" then
        local name = player:get_player_name()
        local search_term = fields.search or ""
        local page = tonumber(fields.page) or 1

        if fields.close or fields.quit then
            minetest.close_formspec(name, "erai:log_viewer")
            return
        elseif fields.search_button then
            minetest.chatcommands["logs"].func(name, search_term .. " 1")
        elseif fields.clear_button then
            minetest.chatcommands["logs"].func(name, " 1")
        elseif fields.refresh then
            minetest.chatcommands["logs"].func(name, search_term .. " " .. page)
        elseif fields.prev_page then
            page = math.max(1, page - 1)
            minetest.chatcommands["logs"].func(name, search_term .. " " .. page)
        elseif fields.next_page then
            page = page + 1
            minetest.chatcommands["logs"].func(name, search_term .. " " .. page)
        end
    end
end)