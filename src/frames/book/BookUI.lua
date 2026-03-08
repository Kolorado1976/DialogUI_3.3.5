-- Book UI для DialogUI (WoW 3.3.5)
local addonName, addon = ...

-- Константы
local BOOK_FRAME_WIDTH = 600
local BOOK_FRAME_HEIGHT = 700
local TEXT_AREA_WIDTH = 520
local TEXT_AREA_HEIGHT = 520

-- Фрейм книги
local BookFrame = nil
local isLoading = false
local updateTimer = nil
local bookData = {}

-- СОЗДАЕМ ШРИФТ ИЗ ВАШЕЙ ПАПКИ (БЕЗ ОБВОДКИ)
local BookTextFont = CreateFont("DDialogBookTextFont")
BookTextFont:SetFont("Interface\\AddOns\\DialogUI\\src\\assets\\font\\Expressway.ttf", 16, "")

-- Функция для создания текстуры кнопки с фоном пергамента
local function SetButtonParchmentBackground(button)
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\AddOns\\DialogUI\\src\\assets\\art\\parchment\\OptionBackground-Common")
    bg:SetAllPoints(button)
    bg:SetTexCoord(0, 1, 0, 1)
    button.bgTexture = bg
    
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\AddOns\\DialogUI\\src\\assets\\art\\parchment\\OptionBackground-Hollow")
    highlight:SetAllPoints(button)
    highlight:SetTexCoord(0, 1, 0, 1)
    highlight:SetBlendMode("ADD")
    button:SetHighlightTexture(highlight)
    
    local pushed = button:CreateTexture(nil, "OVERLAY")
    pushed:SetTexture("Interface\\AddOns\\DialogUI\\src\\assets\\art\\parchment\\OptionBackground-Grey")
    pushed:SetAllPoints(button)
    pushed:SetTexCoord(0, 1, 0, 1)
    pushed:SetBlendMode("ADD")
    pushed:SetAlpha(0.5)
    button:SetPushedTexture(pushed)
    
    button:SetPushedTextOffset(2, -2)
end

-- Создание основного фрейма
local function CreateBookFrame()
    if BookFrame then return BookFrame end
    
    local frame = CreateFrame("Frame", "DDialogBookFrame", UIParent)
    frame:SetSize(BOOK_FRAME_WIDTH, BOOK_FRAME_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetFrameLevel(100)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    
    frame:SetScript("OnHide", function(self)
        isLoading = false
        if updateTimer then
            updateTimer:Hide()
        end
    end)
    
    frame:Hide()
    
    tinsert(UISpecialFrames, frame:GetName())
    
    local parchment = frame:CreateTexture(nil, "BACKGROUND")
    parchment:SetTexture("Interface\\AddOns\\DialogUI\\src\\assets\\art\\book\\TextureKit-Parchment")
    parchment:SetAllPoints(frame)
    parchment:SetTexCoord(0, 1, 0, 1)
    
    -- Заголовок книги (БЕЗ ОБВОДКИ)
    local titleText = frame:CreateFontString(nil, "OVERLAY")
    titleText:SetPoint("TOP", frame, "TOP", 0, -40)
    titleText:SetTextColor(0.2, 0.1, 0.05, 1)
    titleText:SetFont("Interface\\AddOns\\DialogUI\\src\\assets\\font\\Expressway.ttf", 20, "")
    frame.titleText = titleText
    
    -- ScrollFrame для текста
    local scrollFrame = CreateFrame("ScrollFrame", "DDialogBookScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 40, -80)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -40, 100)
    
    -- Контейнер для текста
    local contentFrame = CreateFrame("Frame", nil, scrollFrame)
    contentFrame:SetSize(TEXT_AREA_WIDTH, TEXT_AREA_HEIGHT)
    scrollFrame:SetScrollChild(contentFrame)
    
    -- НОМЕР СТРАНИЦЫ над текстом, желтый, формат "~ 1 ~"
    local pageText = contentFrame:CreateFontString(nil, "OVERLAY")
    pageText:SetPoint("TOP", contentFrame, "TOP", 0, -5)
    pageText:SetTextColor(1, 0.82, 0, 1)  -- Желтый цвет (как золото WoW)
    pageText:SetFont("Interface\\AddOns\\DialogUI\\src\\assets\\font\\Expressway.ttf", 16, "")
    frame.pageText = pageText
    
    -- Текстовое поле (под номером страницы)
    local bodyText = contentFrame:CreateFontString(nil, "OVERLAY")
    bodyText:SetFontObject(BookTextFont)
    bodyText:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 10, -30)  -- Отступ сверху для номера страницы
    bodyText:SetPoint("TOPRIGHT", contentFrame, "TOPRIGHT", -10, -30)
    bodyText:SetJustifyH("LEFT")
    bodyText:SetJustifyV("TOP")
    bodyText:SetSpacing(5)
    bodyText:SetTextColor(0.1, 0.05, 0.02, 1)
    bodyText:SetWidth(TEXT_AREA_WIDTH - 30)
    frame.bodyText = bodyText
    frame.contentFrame = contentFrame
    frame.scrollFrame = scrollFrame
    
    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
    closeButton:SetScript("OnClick", function()
        frame:Hide()
        CloseItemText()
    end)
    
    -- Кнопка "Назад" - поднята выше, текст БЕЛЫЙ
    local prevButton = CreateFrame("Button", nil, frame)
    prevButton:SetSize(120, 30)
    prevButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 50, 40)
    prevButton:SetScript("OnClick", function()
        if ItemTextPrevPage then
            ItemTextPrevPage()
            isLoading = true
        end
    end)
    
    local prevText = prevButton:CreateFontString(nil, "OVERLAY")
    prevText:SetFont("Interface\\AddOns\\DialogUI\\src\\assets\\font\\Expressway.ttf", 14, "")
    prevText:SetTextColor(1, 1, 1, 1)  -- БЕЛЫЙ цвет текста
    prevText:SetText("<< Назад")
    prevText:SetPoint("CENTER")
    prevButton:SetFontString(prevText)
    SetButtonParchmentBackground(prevButton)
    frame.prevButton = prevButton
    
    -- Кнопка "Вперед" - поднята выше, текст БЕЛЫЙ
    local nextButton = CreateFrame("Button", nil, frame)
    nextButton:SetSize(120, 30)
    nextButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -50, 40)
    nextButton:SetScript("OnClick", function()
        if ItemTextNextPage then
            ItemTextNextPage()
            isLoading = true
        end
    end)
    
    local nextText = nextButton:CreateFontString(nil, "OVERLAY")
    nextText:SetFont("Interface\\AddOns\\DialogUI\\src\\assets\\font\\Expressway.ttf", 14, "")
    nextText:SetTextColor(1, 1, 1, 1)  -- БЕЛЫЙ цвет текста
    nextText:SetText("Вперед >>")
    nextText:SetPoint("CENTER")
    nextButton:SetFontString(nextText)
    SetButtonParchmentBackground(nextButton)
    frame.nextButton = nextButton
    
    BookFrame = frame
    return BookFrame
end

local function CleanText(text)
    if not text then return "" end
    text = text:gsub("<[^>]+>", "")
    text = text:gsub("&nbsp;", " ")
    text = text:gsub("&amp;", "&")
    text = text:gsub("&quot;", '"')
    text = text:gsub("&lt;", "<")
    text = text:gsub("&gt;", ">")
    return text
end

function addon:UpdateBookText()
    if not BookFrame or not BookFrame:IsShown() then return end
    
    local itemName = ItemTextGetItem and ItemTextGetItem()
    local rawText = ItemTextGetText and ItemTextGetText()
    
    if not itemName and bookData.title then
        itemName = bookData.title
    end
    
    if not rawText and bookData.text then
        rawText = bookData.text
    end
    
    if not itemName then
        return
    end
    
    local text = CleanText(rawText or "")
    local title = itemName or "Книга"
    
    bookData.title = title
    bookData.text = text
    bookData.page = ItemTextGetPage and ItemTextGetPage() or 1
    bookData.totalPages = ItemTextGetNumPages and ItemTextGetNumPages() or 1
    bookData.hasPrev = ItemTextHasPrevPage and ItemTextHasPrevPage() or false
    bookData.hasNext = ItemTextHasNextPage and ItemTextHasNextPage() or false
    
    if BookFrame.bodyText:GetText() ~= text or BookFrame.titleText:GetText() ~= title then
        BookFrame.titleText:SetText(title)
        BookFrame.bodyText:SetText(text)
        
        local textHeight = BookFrame.bodyText:GetStringHeight()
        -- Добавляем отступ для номера страницы
        BookFrame.contentFrame:SetHeight(math.max(textHeight + 50, TEXT_AREA_HEIGHT))
        BookFrame.scrollFrame:SetVerticalScroll(0)
    end
    
    addon:UpdateNavigation()
end

function addon:UpdateNavigation()
    if not BookFrame or not BookFrame:IsShown() then return end
    
    local hasPrev = bookData.hasPrev or false
    local hasNext = bookData.hasNext or false
    local currentPage = bookData.page or 1
    local totalPages = bookData.totalPages or 1
    
    -- Получаем актуальные данные из API
    if ItemTextHasPrevPage then
        hasPrev = ItemTextHasPrevPage()
        print("|cff00ff00[DialogUI] hasPrev:|r " .. tostring(hasPrev))
    end
    if ItemTextHasNextPage then
        hasNext = ItemTextHasNextPage()
    end
    if ItemTextGetPage then
        currentPage = ItemTextGetPage() or currentPage
    end
    if ItemTextGetNumPages then
        totalPages = ItemTextGetNumPages() or totalPages
    end
    
    -- Обновляем номер страницы в формате "~ 1 ~", желтый цвет
    if totalPages > 1 then
        BookFrame.pageText:SetText(string.format("~ %d ~", currentPage))
        BookFrame.pageText:Show()
    else
        BookFrame.pageText:Hide()
    end
    
    -- Кнопка Назад - показываем если есть предыдущая страница
    if hasPrev then
        BookFrame.prevButton:Show()
        print("|cff00ff00[DialogUI] Показываю кнопку Назад|r")
    else
        BookFrame.prevButton:Hide()
    end
    
    -- Кнопка Вперед - показываем если есть следующая страница
    if hasNext then
        BookFrame.nextButton:Show()
    else
        BookFrame.nextButton:Hide()
    end
end

local function StartUpdateTimer()
    if not updateTimer then
        updateTimer = CreateFrame("Frame")
    end
    
    local attempts = 0
    updateTimer:Show()
    updateTimer:SetScript("OnUpdate", function(self, elapsed)
        attempts = attempts + 1
        
        if attempts % 5 == 0 then
            addon:UpdateBookText()
        end
        
        if attempts > 100 or not BookFrame or not BookFrame:IsShown() then
            self:SetScript("OnUpdate", nil)
            self:Hide()
            isLoading = false
        end
    end)
end

local function ShowCustomBook()
    print("|cff00ff00[DialogUI] Открытие книги...|r")
    
    bookData = {}
    
    local frame = CreateBookFrame()
    
    isLoading = true
    
    frame.titleText:SetText("Загрузка...")
    frame.bodyText:SetText("Загрузка текста...")
    frame.pageText:Hide()
    frame.prevButton:Hide()
    frame.nextButton:Hide()
    frame:Show()
    
    StartUpdateTimer()
end

-- ПОЛНОЕ ОТКЛЮЧЕНИЕ СТАНДАРТНОГО ФРЕЙМА
local function DisableDefaultBookFrame()
    if ItemTextFrame then
        ItemTextFrame:Hide()
        ItemTextFrame:UnregisterAllEvents()
        ItemTextFrame:SetScript("OnShow", nil)
        ItemTextFrame:SetScript("OnEvent", nil)
        ItemTextFrame:SetScript("OnHide", nil)
    end
    
    _G.ItemTextFrame_Show = function()
        ShowCustomBook()
    end
end

DisableDefaultBookFrame()

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == "Blizzard_ItemText" or arg1 == addonName then
            DisableDefaultBookFrame()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        DisableDefaultBookFrame()
    end
end)

-- Обработчик событий книги
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ITEM_TEXT_BEGIN")
eventFrame:RegisterEvent("ITEM_TEXT_READY")
eventFrame:RegisterEvent("ITEM_TEXT_CLOSED")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ITEM_TEXT_BEGIN" then
        isLoading = true
        if not BookFrame or not BookFrame:IsShown() then
            ShowCustomBook()
        end
        
    elseif event == "ITEM_TEXT_READY" then
        if BookFrame and BookFrame:IsShown() then
            addon:UpdateBookText()
        end
        
    elseif event == "ITEM_TEXT_CLOSED" then
        isLoading = false
    end
end)

-- API
addon.BookFrame = {
    Show = function(title, text) 
        local frame = CreateBookFrame()
        frame.titleText:SetText(title or "Книга")
        frame.bodyText:SetText(CleanText(text or ""))
        local textHeight = frame.bodyText:GetStringHeight()
        frame.contentFrame:SetHeight(math.max(textHeight + 50, TEXT_AREA_HEIGHT))
        frame.pageText:Hide()
        frame.prevButton:Hide()
        frame.nextButton:Hide()
        frame:Show()
    end,
    Hide = function() 
        if BookFrame then BookFrame:Hide() end 
    end,
    IsShown = function() 
        return BookFrame and BookFrame:IsShown() 
    end,
    GetFrame = function() 
        return CreateBookFrame() 
    end,
    UpdateText = function()
        addon:UpdateBookText()
    end
}