--[[--
Web search for selected text / dictionary lookups (KOReader Android). v12.
Logs every stage to /storage/emulated/0/koreader/web-search-patch.log.
Errors are logged, never raised.
APIs verified against koreader v2026.07.1.
--]]--

local LOG_PATH = "/storage/emulated/0/koreader/web-search-patch.log"

local function patch_log(msg)
    local ok = pcall(function()
        local f = io.open(LOG_PATH, "a")
        if f then
            f:write(os.date("%H:%M:%S "), msg, "\n")
            f:close()
        end
    end)
end

local ok_all, err = xpcall(function()
    patch_log("PATCH LOADED (v12)")

    local Device = require("device")
    local util = require("util")
    local logger = require("logger")
    local _ = require("gettext")

    if not Device.canOpenLink or not Device:canOpenLink() then
        patch_log("SKIP: Device:openLink unavailable")
        return
    end
    patch_log("openLink available")

    local SEARCH_URL = "https://www.google.com/search?q="
    local WEB_ICON = "lookup.wikipedia" -- fallback when Zen UI is absent

    -- Zen UI ships a clear globe icon, but does not register it by default.
    -- Register it at runtime and keep the old icon as a safe fallback.
    local function register_web_icon()
        local ok_utils, icon_utils = pcall(require, "common/utils")
        local ok_root, plugin_root = pcall(require, "common/plugin_root")
        if not ok_utils or not ok_root or type(plugin_root) ~= "string" then
            return
        end
        local icon_path = plugin_root .. "/icons/globe.svg"
        local f = io.open(icon_path, "r")
        if not f then return end
        f:close()
        local ok = pcall(icon_utils.registerPluginIcons,
            plugin_root .. "/icons/", { web_search = "globe.svg" }, true)
        if ok then
            WEB_ICON = "web_search"
            patch_log("web icon: globe")
        end
    end
    register_web_icon()

    local function url_encode(str)
        str = str:gsub("\r", " "):gsub("\n", " ")
        return (str:gsub("([^%w%-_%.~ ])", function(c)
            return string.format("%%%02X", string.byte(c))
        end):gsub(" ", "+"))
    end

    local function web_search(text)
        if not text or text == "" then return end
        text = util.cleanupSelectedText(text)
        if text == "" then return end
        patch_log("web_search: " .. text)
        Device:openLink(SEARCH_URL .. url_encode(text))
    end

    -- Zen UI clears __ZEN_UI_PLUGIN after applying its reader patches.
    -- Recover its captured config from the wrapper's upvalues when needed.
    local function find_plugin_config(value, seen, depth)
        if type(value) ~= "function" or (depth or 0) > 6 then return nil end
        seen = seen or {}
        if seen[value] then return nil end
        seen[value] = true
        local index = 1
        while true do
            local ok, name, upvalue = pcall(debug.getupvalue, value, index)
            if not ok or not name then break end
            if name == "_plugin_ref" and type(upvalue) == "table"
                    and type(upvalue.config) == "table" then
                return upvalue.config
            end
            if type(upvalue) == "function" then
                local config = find_plugin_config(upvalue, seen, (depth or 0) + 1)
                if config then return config end
            end
            index = index + 1
        end
    end

    local function zen_feature_enabled(feature, source_function)
        local zen = rawget(_G, "__ZEN_UI_PLUGIN")
        local config = zen and zen.config
        if type(config) ~= "table" and source_function then
            config = find_plugin_config(source_function)
        end
        local features = type(config) == "table" and config.features
        return type(features) == "table" and features[feature] == true, config
    end

    -- 1) Highlight dialog: ReaderHighlight:init() rebuilds
    -- self._highlight_buttons per reader instance; re-add after original init.
    local ReaderHighlight = require("apps/reader/modules/readerhighlight")
    local highlight_init_original = ReaderHighlight.init
    local install_highlight_compat
    local highlight_compat_wrapper
    local zen_highlight_known = {
        highlight = true,
        search = true,
        translate = true,
        wikipedia = true,
        dictionary = true,
        ai_assistant = true,
    }

    function ReaderHighlight:init()
        highlight_init_original(self)
        patch_log("ReaderHighlight:init wrapper ran")
        if self._highlight_buttons and not self._highlight_buttons["08_web_search"] then
            self:addToHighlightDialog("08_web_search", function(this)
                return {
                    text = _("Web search"),
                    callback = function()
                        local text = this.selected_text and this.selected_text.text
                        this:onClose()
                        web_search(text)
                    end,
                }
            end)
        end
        if install_highlight_compat then
            install_highlight_compat()
        end
        local keys = {}
        for k in pairs(self._highlight_buttons) do table.insert(keys, k) end
        table.sort(keys)
        patch_log("highlight buttons now: " .. table.concat(keys, ","))
    end

    -- Zen UI replaces ReaderHighlight:onShowHighlightMenu and filters out
    -- third-party buttons unless its "Show other items" setting is enabled.
    -- Temporarily expose only our button while Zen builds its dialog, so other
    -- plugin actions do not suddenly clutter the user's popup.
    install_highlight_compat = function()
        local current = ReaderHighlight.onShowHighlightMenu
        if type(current) ~= "function" or current == highlight_compat_wrapper then
            return
        end
        highlight_compat_wrapper = function(self, index)
            local zen_enabled, zen_config = zen_feature_enabled("highlight_lookup", current)
            if not zen_enabled or type(zen_config) ~= "table" then
                patch_log("onShowHighlightMenu fired")
                return current(self, index)
            end

            local lookup_config = zen_config.highlight_lookup
            if type(lookup_config) ~= "table" then
                lookup_config = {}
                zen_config.highlight_lookup = lookup_config
            end
            local old_allow_unknown = lookup_config.allow_unknown_items
            local buttons = self._highlight_buttons
            local removed = {}
            local old_web_button

            if buttons then
                for key, fn_button in pairs(buttons) do
                    local key_name = type(key) == "string"
                        and (key:match("^%d+_(.*)$") or key) or ""
                    if key ~= "08_web_search" and not zen_highlight_known[key_name] then
                        removed[key] = fn_button
                        buttons[key] = nil
                    end
                end
                old_web_button = buttons["08_web_search"]
                if old_web_button then
                    buttons["08_web_search"] = function(this, button_index)
                        local button = old_web_button(this, button_index)
                        if type(button) == "table" then
                            button.text = nil
                            button.icon = WEB_ICON
                        end
                        return button
                    end
                end
            end

            lookup_config.allow_unknown_items = true
            patch_log("onShowHighlightMenu fired; Zen compatibility enabled")
            local ok, result = pcall(current, self, index)

            if buttons then
                if old_web_button then
                    buttons["08_web_search"] = old_web_button
                else
                    buttons["08_web_search"] = nil
                end
                for key, fn_button in pairs(removed) do
                    buttons[key] = fn_button
                end
            end
            lookup_config.allow_unknown_items = old_allow_unknown

            if not ok then error(result) end
            return result
        end
        ReaderHighlight.onShowHighlightMenu = highlight_compat_wrapper
        patch_log("highlight Zen compatibility installed")
    end
    install_highlight_compat()

    -- 2) Dictionary popup: same wrapper treatment; also self-heals the
    -- PERSISTED layout (dict_button_config, PR #15184).
    local ReaderDictionary = require("apps/reader/modules/readerdictionary")
    local dictionary_init_original = ReaderDictionary.init

    function ReaderDictionary:init()
        dictionary_init_original(self)
        patch_log("ReaderDictionary:init wrapper ran; addToDictButtons=" .. tostring(type(self.addToDictButtons)))
        if type(self.addToDictButtons) == "function" then
            self:addToDictButtons({
                id = "web_search",
                menu_text = _("Web search"),
                text = _("Web search"),
                callback = function(popup)
                    local text = popup.lookupword or popup.word
                    popup:onClose()
                    web_search(text)
                end,
            })

            -- KOReader appends newly registered buttons to a new row when
            -- they are absent from default_layout. On a tablet that row can
            -- fall below the visible dictionary popup. Put this button into
            -- the existing last row first; populatePluginButtons then keeps
            -- it there instead of creating row 4.
            local default_layout = self.default_layout
            local default_present = false
            if default_layout then
                for _, row in ipairs(default_layout) do
                    for _, id in ipairs(row) do
                        if id == "web_search" then
                            default_present = true
                            break
                        end
                    end
                    if default_present then break end
                end
                if not default_present and #default_layout > 0 then
                    local last_row = default_layout[#default_layout]
                    if last_row and #last_row < 4 then
                        table.insert(last_row, "web_search")
                        patch_log("default_layout: placed web_search in last row")
                    else
                        table.insert(default_layout, { "web_search" })
                        patch_log("default_layout: added web_search as new row")
                    end
                end
            end

            local cfg = G_reader_settings:readSetting("dict_button_config")
            patch_log("dict_button_config exists=" .. tostring(cfg ~= nil))
            if cfg and cfg.order then
                local present = false
                for _, id in ipairs(cfg.order) do
                    if id == "web_search" then present = true break end
                end
                if not present then
                    table.insert(cfg.order, "web_search")
                    if cfg.layout and #cfg.layout > 0 then
                        local last_row = cfg.layout[#cfg.layout]
                        if #last_row < 4 then
                            table.insert(last_row, "web_search")
                        else
                            table.insert(cfg.layout, { "web_search" })
                            if cfg.row_count then table.insert(cfg.row_count, 1) end
                        end
                        if cfg.row_count then
                            cfg.row_count[#cfg.layout] = #cfg.layout[#cfg.layout]
                        end
                    end
                    G_reader_settings:saveSetting("dict_button_config", cfg)
                    patch_log("self-heal: appended web_search to saved layout")
                else
                    patch_log("self-heal: web_search already in saved layout")
                end
            end
        end
    end

    -- Zen UI also replaces DictQuickLookup:buildButtonLayout and drops
    -- unknown IDs. Re-apply after Zen's wrapper and append a globe icon to its
    -- icon row. On plain KOReader the original text button is left untouched.
    local okd, DictQuickLookup = pcall(require, "ui/widget/dictquicklookup")
    if okd and DictQuickLookup and DictQuickLookup.buildButtonLayout then
        local dict_layout_wrapper

        local function layout_has_button(layout, button_id)
            if not layout then return false end
            for _, row in ipairs(layout) do
                for _, button in ipairs(row) do
                    if button and button.id == button_id then return true end
                end
            end
            return false
        end

        local function install_dict_compat()
            local current = DictQuickLookup.buildButtonLayout
            if type(current) ~= "function" or current == dict_layout_wrapper then
                return
            end
            dict_layout_wrapper = function(self)
                local layout = current(self)
                if layout and not layout_has_button(layout, "web_search") then
                    if not layout[1] then layout[1] = {} end
                    table.insert(layout[1], {
                        id = "web_search",
                        icon = WEB_ICON,
                        enabled = true,
                        callback = function()
                            local text = self.lookupword or self.word
                            self:onClose()
                            web_search(text)
                        end,
                    })
                    patch_log("Zen compatibility: appended web_search icon")
                end

                local rows = {}
                if layout then
                    for r, row in ipairs(layout) do
                        local ids = {}
                        for _, button in ipairs(row) do
                            table.insert(ids, button.id or tostring(button))
                        end
                        table.insert(rows, r .. ":[" .. table.concat(ids, " ") .. "]")
                    end
                end
                patch_log("buildButtonLayout -> " .. (#rows > 0 and table.concat(rows, " | ") or "EMPTY"))
                return layout
            end
            DictQuickLookup.buildButtonLayout = dict_layout_wrapper
            patch_log("buildButtonLayout compatibility installed")
        end

        install_dict_compat()
        local dict_init_original = DictQuickLookup.init
        DictQuickLookup.init = function(self, ...)
            install_dict_compat()
            return dict_init_original(self, ...)
        end
    end

    patch_log("wrappers installed")
end, debug.traceback)

if not ok_all then
    patch_log("PATCH FAILED: " .. tostring(err))
end
