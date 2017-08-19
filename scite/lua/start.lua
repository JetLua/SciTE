local L = {
    pos = {
        find = 0,
        tag = 0
    },
    flag = {
        find = false
    }
}

local l = 0

-- 构造函数
function L:new()
    o = {}
    setmetatable(o, self)
    self.__index = self
    return o
end

-- tab替换
function L:replace()
    flag = false
    for x in editor:match('\t') do
        x:replace('    ')
        flag = true
    end
--     if flag and props['FileName'] ~= '' then
--         scite.MenuCommand(IDM_SAVE)
--     end
end

-- 双击查找
function L:find()
    word = editor:GetSelText()
    if string.find(editor:GetSelText(), '^[%s]*$') then
        return
    end
    editor:IndicatorClearRange(0, editor.TextLength)
    editor.IndicFore[1] = 0xff0000
    editor.IndicUnder[1] = 0
    editor.IndicStyle[1] = 7
    editor.IndicAlpha[1] = 255
    editor.IndicOutlineAlpha[1] = 255
    editor.IndicatorCurrent = 1
    for x in editor:match(word) do
        editor:IndicatorFillRange(x.pos, x.len)
    end
    self.pos.find = editor.CurrentPos
    self.flag.find = true
end

-- 检测编码
function L:codePage()
    s = editor:GetText()
    l = string.len(s)
    if l == 0 then
        scite.MenuCommand(IDM_ENCODING_UCOOKIE)
        return
    end
    i = 1
    while i < l do
        code = string.byte(s, i)
        if code <= 127 then
            i = i + 1
        elseif code >= 192 and code <= 223 then
            i = i + 2
        elseif code >= 224 and code <= 239 then
            i = i + 3
        elseif code >= 240 and code <= 247 then
            i = i + 4
        else
            break
        end
    end
    if i == l then
        scite.MenuCommand(IDM_ENCODING_UCOOKIE)
    else
        scite.MenuCommand(IDM_ENCODING_DEFAULT)
    end
end

function L:tagMatch()
    editor.IndicFore[0] = 0xffffff
    editor.IndicUnder[0] = 0
    editor.IndicStyle[0] = 6
    editor.IndicAlpha[0] = 255
    editor.IndicOutlineAlpha[0] = 255
    editor.IndicatorCurrent = 0
    self.pos.tag = editor.CurrentPos
    pos = editor.CurrentPos
    tag = false
    count = 0
    for x in editor:match("<[/a-zA-Z]+[^<>]+>", SCFIND_REGEXP) do
        if pos > x.pos and pos < x.pos + x.len then
            editor:IndicatorFillRange(x.pos, x.len)
            -- 自闭合标签
            if string.find(x.text, "<[^<>]/>") then
                return
            end
            -- 光标在标签后部
            if string.find(x.text, "</[^<>]+>") then
                self:back(x)
                return
            end
            -- 光标在标签前部
            if string.find(x.text, "<[^<>]+>") then
                self:pre(x)
                return
            end
        end
    end
end

function L:back(o)
    _, _, tag = string.find(o.text, "</(%w+)")
    if tag == nil then
        return
    end
    li = {}
    count = 0
    flag = false
    for x in editor:match("</*"..tag.."[^<>]*>", SCFIND_REGEXP) do
        table.insert(li, {text=x.text, pos=x.pos, len=x.len})
    end
    table.sort(li, function(a, b)
        return a.pos > b.pos
    end)
    for k, v in pairs(li) do
        if flag then
            _, _, _tag = string.find(v.text, "</*(%w+)")
            if _tag == tag then
                if string.find(v.text, "</"..tag) then
                    count = count + 1
                end

                if string.find(v.text, "<"..tag) then
                    if count == 0 then
                        editor:IndicatorFillRange(v.pos, v.len)
                        return
                    else
                        count = count - 1
                    end
                end
            end
        end
        if o.pos == v.pos then
            flag = true
        end
    end
end

function L:pre(o)
    _, _, tag = string.find(o.text, "<(%w+)")
    if tag == nil then
        return
    end
    li = {}
    count = 0
    flag = false
    for x in editor:match("</*"..tag.."[^<>]*>", SCFIND_REGEXP) do
        table.insert(li, {text=x.text, pos=x.pos, len=x.len})
    end
    for k, v in pairs(li) do
        if flag then
            _, _, _tag = string.find(v.text, "</*(%w+)")
            if _tag == tag then
                if string.find(v.text, "<"..tag) then
                    count = count + 1
                end

                if string.find(v.text, "</"..tag) then
                    if count == 0 then
                        editor:IndicatorFillRange(v.pos, v.len)
                        return
                    else
                        count = count - 1
                    end
                end
            end
        end
        if o.pos == v.pos then
            flag = true
        end
    end
end

-- 自动完成
function L:autoComplete(s)
    -- 多列编辑模式则关闭
    if editor.Selections ~= 1 then
        return
    end

    -- 输入的不是字符和-_则关闭
    if not string.find(s, "[%w_-]") then
        return
    end

    li = {}
    txt = editor:GetText()
    e = editor.CurrentPos
    s = editor:WordStartPosition(e, true)
    editor:SetSel(s, e)
    str = editor:GetSelText()
    editor:SetEmptySelection(e)

    if str == "" then
        return
    end

    for x in string.gmatch(txt, "[%w_-]+") do
        flag = true
        if string.find(string.upper(x), "^" .. string.upper(str)) then
            for k, v in pairs(li) do
                if v == x then
                    flag = false
                    break
                end
            end
            if flag then
                table.insert(li, x)
            end
        end
    end

    must = ""
    table.sort(li)

    for k, v in pairs(li) do
        if v ~= str then
            if must == "" then
                must = must .. v
            else
                must = must .. " " .. v
            end
        end
    end
    if must == "" then
        return
    end
    editor.AutoCAutoHide = true
    editor.AutoCSeparator = 32
    editor.AutoCIgnoreCase = true
    editor.AutoCCaseInsensitiveBehaviour = 1

    if not editor:AutoCActive() then
        editor.AutoCOrder = 1
        editor:AutoCShow(string.len(str), must)
    end
end

-- 创建实例


-- 双击事件
function OnDoubleClick()
    if type(l) ~= "table" then
        l = L:new()
    end
    l:find()
end

-- 标签更新
function OnClear()
    if props['FileName'] == "" then
        scite.MenuCommand(IDM_ENCODING_UCOOKIE)
    end
end

function OnOpen(s)
    if type(l) ~= "table" then
        l = L:new()
    end
--     l:replace()
    l:codePage()
end

-- 输入字符
function OnChar(s)
    if type(l) ~= "table" then
        l = L:new()
    end
    l:autoComplete(s)
end

-- UI更新
function OnUpdateUI()
    if type(l) ~= "table" then
        l = L:new()
    end

    if l.flag.find then
        if string.find(editor:GetSelText(), "^[%s]*$") then
            if editor.CurrentPos ~= l.pos.find then
                editor:IndicatorClearRange(0, editor.TextLength)
                l.flag.find = false
            end
        end
    else
        if l.pos.tag ~= editor.CurrentPos then
            editor:IndicatorClearRange(0, editor.TextLength)
        end
        if string.find(editor:GetCurLine(), "<[^<>]+>") then
            l:tagMatch()
        end
    end
end
