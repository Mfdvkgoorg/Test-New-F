local httpService = game:GetService("HttpService")

-- 🔒 ระบบเข้ารหัสลับ (XOR + Base64) ระดับสูงด้วย bit32 (ใส่ไว้บนสุดของไฟล์)
local SECRET_KEY = "TaoBa"
local B64C = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64M = {}
for i = 1, 64 do B64M[B64C:sub(i, i)] = i - 1 end

local bxor = bit32 and bit32.bxor or bit and bit.bxor

local function b64enc(str)
    local out = {}
    local len = #str
    for i = 1, len, 3 do
        local n1, n2, n3 = string.byte(str, i, i+2)
        n2 = n2 or 0
        n3 = n3 or 0
        local v = n1 * 65536 + n2 * 256 + n3
        local c1 = math.floor(v / 262144) % 64
        local c2 = math.floor(v / 4096) % 64
        local c3 = math.floor(v / 64) % 64
        local c4 = v % 64
        table.insert(out, B64C:sub(c1+1, c1+1))
        table.insert(out, B64C:sub(c2+1, c2+1))
        table.insert(out, i+1 <= len and B64C:sub(c3+1, c3+1) or "=")
        table.insert(out, i+2 <= len and B64C:sub(c4+1, c4+1) or "=")
    end
    return table.concat(out)
end

local function b64dec(s)
    s = s:gsub("[^A-Za-z0-9+/]", "")
    local out = {}
    local n = 0
    for i = 1, #s, 4 do
        local v, cnt = 0, 0
        for j = 0, 3 do
            local ch = s:sub(i + j, i + j)
            v = v * 64 + (B64M[ch] or 0)
            if ch ~= "" then cnt = cnt + 1 end
        end
        local bytes = cnt - 1
        if bytes >= 1 then n = n + 1 out[n] = string.char(math.floor(v / 65536) % 256) end
        if bytes >= 2 then n = n + 1 out[n] = string.char(math.floor(v / 256) % 256) end
        if bytes >= 3 then n = n + 1 out[n] = string.char(v % 256) end
    end
    return table.concat(out)
end

local function cryptXOR(data, key)
    local result = {}
    for i = 1, #data do
        local byte = data:byte(i)
        local keyByte = key:byte((i - 1) % #key + 1)
        result[i] = string.char(bxor(byte, keyByte))
    end
    return table.concat(result)
end

local function EncryptConfig(jsonStr)
    return b64enc(cryptXOR(jsonStr, SECRET_KEY))
end

local function DecryptConfig(encStr)
    return cryptXOR(b64dec(encStr), SECRET_KEY)
end
-- =========================================================================

local SaveManager = {} do
    SaveManager.Folder = "FluentSettings"
    SaveManager.Ignore = {}
    SaveManager.Parser = {
        Toggle = {
            Save = function(idx, object) 
                return { type = "Toggle", idx = idx, value = object.Value } 
            end,
            Load = function(idx, data)
                if SaveManager.Options[idx] then 
                    SaveManager.Options[idx]:SetValue(data.value)
                end
            end,
        },
        Slider = {
            Save = function(idx, object)
                return { type = "Slider", idx = idx, value = tostring(object.Value) }
            end,
            Load = function(idx, data)
                if SaveManager.Options[idx] then 
                    SaveManager.Options[idx]:SetValue(data.value)
                end
            end,
        },
        Dropdown = {
            Save = function(idx, object)
                return { type = "Dropdown", idx = idx, value = object.Value, mutli = object.Multi }
            end,
            Load = function(idx, data)
                if SaveManager.Options[idx] then 
                    SaveManager.Options[idx]:SetValue(data.value)
                end
            end,
        },
        Colorpicker = {
            Save = function(idx, object)
                return { type = "Colorpicker", idx = idx, value = object.Value:ToHex(), transparency = object.Transparency }
            end,
            Load = function(idx, data)
                if SaveManager.Options[idx] then 
                    SaveManager.Options[idx]:SetValueRGB(Color3.fromHex(data.value), data.transparency)
                end
            end,
        },
        Keybind = {
            Save = function(idx, object)
                return { type = "Keybind", idx = idx, mode = object.Mode, key = object.Value }
            end,
            Load = function(idx, data)
                if SaveManager.Options[idx] then 
                    SaveManager.Options[idx]:SetValue(data.key, data.mode)
                end
            end,
        },

        Input = {
            Save = function(idx, object)
                return { type = "Input", idx = idx, text = object.Value }
            end,
            Load = function(idx, data)
                if SaveManager.Options[idx] and type(data.text) == "string" then
                    SaveManager.Options[idx]:SetValue(data.text)
                end
            end,
        },
    }

    function SaveManager:SetIgnoreIndexes(list)
        for _, key in next, list do
            self.Ignore[key] = true
        end
    end

    function SaveManager:SetFolder(folder)
        self.Folder = folder;
        self:BuildFolderTree()
    end

    function SaveManager:Save(name)
        if (not name) then
            return false, "no config file is selected"
        end

        local fullPath = self.Folder .. "/settings/" .. name .. ".json"

        local data = {
            objects = {}
        }

        for idx, option in next, SaveManager.Options do
            if not self.Parser[option.Type] then continue end
            if self.Ignore[idx] then continue end

            table.insert(data.objects, self.Parser[option.Type].Save(idx, option))
        end 

        local success, encoded = pcall(httpService.JSONEncode, httpService, data)
        if not success then
            return false, "failed to encode data"
        end

        writefile(fullPath, encoded)
        return true
    end

    function SaveManager:Load(name)
        if (not name) then
            return false, "no config file is selected"
        end
        
        local file = self.Folder .. "/settings/" .. name .. ".json"
        if not isfile(file) then return false, "invalid file" end

        local success, decoded = pcall(httpService.JSONDecode, httpService, readfile(file))
        if not success then return false, "decode error" end

        for _, option in next, decoded.objects do
            if self.Parser[option.type] then
                task.spawn(function() self.Parser[option.type].Load(option.idx, option) end)
            end
        end

        return true
    end

    function SaveManager:IgnoreThemeSettings()
        self:SetIgnoreIndexes({ 
            "InterfaceTheme", "AcrylicToggle", "TransparentToggle", "MenuKeybind"
        })
    end

    function SaveManager:BuildFolderTree()
        local paths = {
            self.Folder,
            self.Folder .. "/settings"
        }

        for i = 1, #paths do
            local str = paths[i]
            if not isfolder(str) then
                makefolder(str)
            end
        end
    end

    function SaveManager:RefreshConfigList()
        local list = listfiles(self.Folder .. "/settings")

        local out = {}
        for i = 1, #list do
            local file = list[i]
            if file:sub(-5) == ".json" then
                local pos = file:find(".json", 1, true)
                local start = pos

                local char = file:sub(pos, pos)
                while char ~= "/" and char ~= "\\" and char ~= "" do
                    pos = pos - 1
                    char = file:sub(pos, pos)
                end

                if char == "/" or char == "\\" then
                    local name = file:sub(pos + 1, start - 1)
                    if name ~= "options" then
                        table.insert(out, name)
                    end
                end
            end
        end
        
        return out
    end

    function SaveManager:SetLibrary(library)
        self.Library = library
        self.Options = library.Options
    end

    function SaveManager:LoadAutoloadConfig()
        if isfile(self.Folder .. "/settings/autoload.txt") then
            local name = readfile(self.Folder .. "/settings/autoload.txt")

            local success, err = self:Load(name)
            if not success then
                return self.Library:Notify({
                    Title = "Interface",
                    Content = "Config loader",
                    SubContent = "Failed to load autoload config: " .. err,
                    Duration = 7
                })
            end

            self.Library:Notify({
                Title = "Interface",
                Content = "Config loader",
                SubContent = string.format("Auto loaded config %q", name),
                Duration = 7
            })
        end
    end

    function SaveManager:BuildConfigSection(tab)
        assert(self.Library, "Must set SaveManager.Library")

        local section = tab:AddSection("Configuration")

        section:AddInput("SaveManager_ConfigName",    { Title = "Config name" })
        section:AddDropdown("SaveManager_ConfigList", { Title = "Config list", Values = self:RefreshConfigList(), AllowNull = true })

        -- 🗑️ เพิ่มปุ่ม Delete Config พร้อมระบบยืนยัน (Confirm Dialog)
        section:AddButton({
            Title = "Delete Config",
            Callback = function()
                local name = SaveManager.Options.SaveManager_ConfigList.Value
                if not name or name == "" then
                    return self.Library:Notify({ Title = "Error", Content = "Please select a config to delete!", Duration = 3 })
                end

                self.Library.Window:Dialog({
                    Title = "⚠️ Confirm Deletion",
                    Content = "แน่ใจหรือไม่ที่จะลบคอนฟิกนี้❗",
                    Buttons = {
                        {
                            Title = "✅ Confirm",
                            Callback = function()
                                local path = self.Folder .. "/settings/" .. name .. ".json"
                                if isfile(path) then
                                    delfile(path)
                                    -- Auto refresh list
                                    SaveManager.Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
                                    SaveManager.Options.SaveManager_ConfigList:SetValue(nil)
                                    self.Library:Notify({
                                        Title = "🗑 Successfully Deleted Config",
                                        Content = "ลบคอนฟิกสำเร็จ✅",
                                        Duration = 5
                                    })
                                end
                            end
                        },
                        { Title = "❌ Cancel" }
                    }
                })
            end
        })

        section:AddButton({
            Title = "Create config",
            Callback = function()
                local name = SaveManager.Options.SaveManager_ConfigName.Value

                if name:gsub(" ", "") == "" then 
                    return self.Library:Notify({
                        Title = "Interface",
                        Content = "Config loader",
                        SubContent = "Invalid config name (empty)",
                        Duration = 7
                    })
                end

                local success, err = self:Save(name)
                if not success then
                    return self.Library:Notify({
                        Title = "Interface",
                        Content = "Config loader",
                        SubContent = "Failed to save config: " .. err,
                        Duration = 7
                    })
                end

                self.Library:Notify({
                    Title = "Interface",
                    Content = "Config loader",
                    SubContent = string.format("Created config %q", name),
                    Duration = 7
                })

                SaveManager.Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
                SaveManager.Options.SaveManager_ConfigList:SetValue(nil)
            end
        })

        section:AddButton({Title = "Load config", Callback = function()
            local name = SaveManager.Options.SaveManager_ConfigList.Value

            local success, err = self:Load(name)
            if not success then
                return self.Library:Notify({
                    Title = "Interface",
                    Content = "Config loader",
                    SubContent = "Failed to load config: " .. err,
                    Duration = 7
                })
            end

            self.Library:Notify({
                Title = "Interface",
                Content = "Config loader",
                SubContent = string.format("Loaded config %q", name),
                Duration = 7
            })
        end})

        section:AddButton({Title = "Overwrite config", Callback = function()
            local name = SaveManager.Options.SaveManager_ConfigList.Value

            local success, err = self:Save(name)
            if not success then
                return self.Library:Notify({
                    Title = "Interface",
                    Content = "Config loader",
                    SubContent = "Failed to overwrite config: " .. err,
                    Duration = 7
                })
            end

            self.Library:Notify({
                Title = "Interface",
                Content = "Config loader",
                SubContent = string.format("Overwrote config %q", name),
                Duration = 7
            })
        end})

        section:AddButton({Title = "Refresh list", Callback = function()
            SaveManager.Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
            SaveManager.Options.SaveManager_ConfigList:SetValue(nil)
        end})

        local AutoloadButton
        AutoloadButton = section:AddButton({Title = "Set as autoload", Description = "Current autoload config: none", Callback = function()
            local name = SaveManager.Options.SaveManager_ConfigList.Value
            writefile(self.Folder .. "/settings/autoload.txt", name)
            AutoloadButton:SetDesc("Current autoload config: " .. name)
            self.Library:Notify({
                Title = "Interface",
                Content = "Config loader",
                SubContent = string.format("Set %q to auto load", name),
                Duration = 7
            })
        end})

        if isfile(self.Folder .. "/settings/autoload.txt") then
            local name = readfile(self.Folder .. "/settings/autoload.txt")
            AutoloadButton:SetDesc("Current autoload config: " .. name)
        end

        -- 🔗 สร้าง Section: Share & Load ล่างสุด
        local shareSection = tab:AddSection("Share & Load")

        shareSection:AddParagraph({
            Title = "How To Import Config",
            Content = "Type Your Desired Name in The 'Config name'\nBox Above Before Pasting Your Code."
        })

        shareSection:AddParagraph({
            Title = "วิธีนำเข้าคอนฟิก",
            Content = "พิมพ์ชื่อที่ต้องการในช่อง 'Config name'ด้านบนก่อน\nแล้วจึงวางโค้ดในช่อง Import"
        })

        shareSection:AddButton({
            Title = "Export Config",
            Description = "ส่งออกการตั้งค่าทั้งหมด",
            Callback = function()
                self.Library.Window:Dialog({
                    Title = "🔗 Auto copy to Clipboard",
                    Content = "ออโต้คัดลอกไปคลิปบอร์ด",
                    Buttons = {
                        {
                            Title = "✅ Confirm",
                            Callback = function()
                                -- ดึงค่า Config ณ ปัจจุบันมาเข้ารหัส
                                local data = { objects = {} }
                                for idx, option in next, SaveManager.Options do
                                    if not self.Parser[option.Type] then continue end
                                    if self.Ignore[idx] then continue end
                                    table.insert(data.objects, self.Parser[option.Type].Save(idx, option))
                                end 

                                local success, encoded = pcall(httpService.JSONEncode, httpService, data)
                                if success then
                                    local encryptedBase64 = EncryptConfig(encoded)
                                    setclipboard(encryptedBase64) -- สั่งคัดลอกลงคลิปบอร์ด
                                    self.Library:Notify({
                                        Title = "🟢Configuration Exported Successfully",
                                        Content = "ส่งออกคอนฟิกสำเร็จ✅",
                                        Duration = 5
                                    })
                                end
                            end
                        },
                        { Title = "❌ Cancel" }
                    }
                })
            end
        })

        local ImportInput
        ImportInput = shareSection:AddInput("SaveManager_ImportConfig", {
            Title = "Import Config",
            Description = "นำเข้าตั้งค่าทั้งหมด",
            Default = "",
            Placeholder = "Paste Config here...",
            Numeric = false,
            Finished = true
        })

        ImportInput:OnChanged(function(value)
            if value and value ~= "" then
                -- ลองถอดรหัสและแปลงกลับเป็น JSON
                local success, result = pcall(function()
                    local decrypted = DecryptConfig(value)
                    return httpService:JSONDecode(decrypted)
                end)

                if success and type(result) == "table" and result.objects then
                    -- ดึงชื่อมาจากช่อง Config Name ถ้าว่างจะสุ่มชื่อให้
                    local name = SaveManager.Options.SaveManager_ConfigName.Value
                    if name:gsub(" ", "") == "" then 
                        name = "TaoBa_" .. math.random(1, 99)
                    end

                    self.Library.Window:Dialog({
                        Title = "Confirm Import",
                        Content = "ยืนยันการนำเข้าคอนฟิกชื่อ: " .. name,
                        Buttons = {
                            {
                                Title = "✅ Confirm",
                                Callback = function()
                                    local path = self.Folder .. "/settings/" .. name .. ".json"
                                    local encoded = httpService:JSONEncode(result)
                                    writefile(path, encoded) -- สร้างไฟล์ JSON
                                    
                                    -- อัพเดตและเลือก Dropdown ให้เป็นอันใหม่
                                    SaveManager.Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
                                    SaveManager.Options.SaveManager_ConfigList:SetValue(name)
                                    
                                    self.Library:Notify({
                                        Title = "🟢Configuration Imported Successfully",
                                        Content = "นำเข้าคอนฟิกสำเร็จ✅",
                                        Duration = 7
                                    })
                                    ImportInput:SetValue("") -- ล้างช่องวาง
                                end
                            },
                            { 
                                Title = "❌ Cancel", 
                                Callback = function() 
                                    ImportInput:SetValue("") 
                                end 
                            }
                        }
                    })
                else
                    self.Library:Notify({
                        Title = "Import Code Is Invalid or Damaged!",
                        Content = "โค้ดนำเข้าไม่ถูกต้องหรือเสียหาย!",
                        Duration = 7
                    })
                    ImportInput:SetValue("")
                end
            end
        end)

        -- อย่าลืมเอาช่อง Import ยัดเข้า Ignore จะได้ไม่ถูกดึงไปเซฟรวมในไฟล์
        SaveManager:SetIgnoreIndexes({ 
            "SaveManager_ConfigList", 
            "SaveManager_ConfigName",
            "SaveManager_ImportConfig"
        })
    end

    SaveManager:BuildFolderTree()
end

return SaveManager

