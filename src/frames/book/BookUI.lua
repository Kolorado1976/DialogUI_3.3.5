-- Book UI для DialogUI (WoW 3.3.5)
local addonName, addon = ...

-- Константы
local BOOK_FRAME_WIDTH = 600
local BOOK_FRAME_HEIGHT = 700
local TEXT_AREA_WIDTH = 520
local TEXT_AREA_HEIGHT = 520

-- Фрейм книги
local BookFrame = nil

-- СОЗДАЕМ ШРИФТ ИЗ ВАШЕЙ ПАПКИ (БЕЗ ОБВОДКИ)
local BookTextFont = CreateFont("DDialogBookTextFont")
BookTextFont:SetFont("Interface\\AddOns\\DialogUI\\src\\assets\\font\\Expressway.ttf", 16, "") -- Убрал "OUTLINE"

-- Создание основного фрейма
local function CreateBookFrame()
    if BookFrame then return BookFrame end
    
    -- Основной фрейм
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
    frame:Hide()
    
    -- Регистрация для закрытия по Escape
    tinsert(UISpecialFrames, frame:GetName())
    
    -- Фон - только ваш пергамент
    local parchment = frame:CreateTexture(nil, "BACKGROUND")
    parchment:SetTexture("Interface\\AddOns\\DialogUI\\src\\assets\\art\\book\\TextureKit-Parchment")
    parchment:SetAllPoints(frame)
    parchment:SetTexCoord(0, 1, 0, 1)
    
    -- Заголовок (БЕЗ ОБВОДКИ)
    local titleText = frame:CreateFontString(nil, "OVERLAY")
    titleText:SetPoint("TOP", frame, "TOP", 0, -40)
    titleText:SetTextColor(0.2, 0.1, 0.05, 1)
    titleText:SetFont("Interface\\AddOns\\DialogUI\\src\\assets\\font\\Expressway.ttf", 20, "") -- Убрал "OUTLINE"
    frame.titleText = titleText
    
    -- ScrollFrame для текста
    local scrollFrame = CreateFrame("ScrollFrame", "DDialogBookScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 40, -80)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -40, 60)
    
    -- Контейнер для текста
    local contentFrame = CreateFrame("Frame", nil, scrollFrame)
    contentFrame:SetSize(TEXT_AREA_WIDTH, TEXT_AREA_HEIGHT)
    scrollFrame:SetScrollChild(contentFrame)
    
    -- Текстовое поле (БЕЗ ОБВОДКИ)
    local bodyText = contentFrame:CreateFontString(nil, "OVERLAY")
    bodyText:SetFontObject(BookTextFont)  -- В шрифте уже убрана обводка
    bodyText:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 10, -10)
    bodyText:SetPoint("TOPRIGHT", contentFrame, "TOPRIGHT", -10, -10)
    bodyText:SetJustifyH("LEFT")
    bodyText:SetJustifyV("TOP")
    bodyText:SetSpacing(5)
    bodyText:SetTextColor(0.1, 0.05, 0.02, 1)
    bodyText:SetWidth(TEXT_AREA_WIDTH - 30)
    frame.bodyText = bodyText
    frame.contentFrame = contentFrame
    frame.scrollFrame = scrollFrame
    
    -- Кнопка закрытия
    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
    closeButton:SetScript("OnClick", function()
        frame:Hide()
        CloseItemText()
    end)
    
    -- Кнопка "Назад"
    local prevButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    prevButton:SetSize(100, 25)
    prevButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 50, 20)
    prevButton:SetText("<< Назад")
    prevButton:SetScript("OnClick", function()
        ItemTextPrevPage()
        addon:UpdateBookText()
    end)
    frame.prevButton = prevButton
    
    -- Кнопка "Вперед"
    local nextButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    nextButton:SetSize(100, 25)
    nextButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -50, 20)
    nextButton:SetText("Вперед >>")
    nextButton:SetScript("OnClick", function()
        ItemTextNextPage()
        addon:UpdateBookText()
    end)
    frame.nextButton = nextButton
    
    -- Индикатор страницы (БЕЗ ОБВОДКИ)
    local pageText = frame:CreateFontString(nil, "OVERLAY")
    pageText:SetPoint("BOTTOM", frame, "BOTTOM", 0, 25)
    pageText:SetTextColor(0.3, 0.2, 0.1, 1)
    pageText:SetFont("Interface\\AddOns\\DialogUI\\src\\assets\\font\\Expressway.ttf", 14, "") -- Убрал "OUTLINE"
    frame.pageText = pageText
    
    BookFrame = frame
    return BookFrame
end

-- Функция для очистки HTML тегов
local function CleanText(text)
    if not text then return "" end
    
    -- Удаляем HTML теги
    text = text:gsub("<[^>]+>", "")
    
    -- Заменяем специальные символы
    text = text:gsub("&nbsp;", " ")
    text = text:gsub("&amp;", "&")
    text = text:gsub("&quot;", '"')
    text = text:gsub("&lt;", "<")
    text = text:gsub("&gt;", ">")
    
    return text
end

-- Обновление текста из игры
function addon:UpdateBookText()
    if not BookFrame or not BookFrame:IsShown() then return end
    
    -- Получаем текст и очищаем его
    local rawText = ItemTextGetText() or ""
    local text = CleanText(rawText)
    
    -- Получаем заголовок
    local title = ItemTextGetItem() or "Книга"
    
    -- Обновляем заголовок
    BookFrame.titleText:SetText(title)
    
    -- Обновляем текст
    BookFrame.bodyText:SetText(text)
    
    -- Подгоняем высоту контейнера под текст
    local textHeight = BookFrame.bodyText:GetStringHeight()
    BookFrame.contentFrame:SetHeight(math.max(textHeight + 20, TEXT_AREA_HEIGHT))
    
    -- Сбрасываем скролл наверх
    BookFrame.scrollFrame:SetVerticalScroll(0)
    
    -- Обновляем кнопки навигации
    local hasPrev = ItemTextHasPrevPage and ItemTextHasPrevPage() or false
    local hasNext = ItemTextHasNextPage and ItemTextHasNextPage() or false
    
    if hasPrev then
        BookFrame.prevButton:Show()
    else
        BookFrame.prevButton:Hide()
    end
    
    if hasNext then
        BookFrame.nextButton:Show()
    else
        BookFrame.nextButton:Hide()
    end
    
    -- Обновляем индикатор страницы
    if hasPrev or hasNext then
        local page = ItemTextGetPage and ItemTextGetPage() or 1
        local totalPages = ItemTextGetNumPages and ItemTextGetNumPages() or 1
        BookFrame.pageText:SetText(string.format("Страница %d из %d", page, totalPages))
        BookFrame.pageText:Show()
    else
        BookFrame.pageText:Hide()
    end
end

-- Функция открытия книги
local function ShowCustomBook()
    print("|cff00ff00DialogUI: Открытие книги|r")
    
    local frame = CreateBookFrame()
    
    -- Получаем и очищаем текст
    local rawText = ItemTextGetText() or "Загрузка текста..."
    local text = CleanText(rawText)
    local title = ItemTextGetItem() or "Книга"
    
    -- Устанавливаем текст
    frame.titleText:SetText(title)
    frame.bodyText:SetText(text)
    
    -- Подгоняем высоту
    local textHeight = frame.bodyText:GetStringHeight()
    frame.contentFrame:SetHeight(math.max(textHeight + 20, TEXT_AREA_HEIGHT))
    
    -- Обновляем навигацию
    local hasPrev = ItemTextHasPrevPage and ItemTextHasPrevPage() or false
    local hasNext = ItemTextHasNextPage and ItemTextHasNextPage() or false
    
    if hasPrev then
        frame.prevButton:Show()
    else
        frame.prevButton:Hide()
    end
    
    if hasNext then
        frame.nextButton:Show()
    else
        frame.nextButton:Hide()
    end
    
    if hasPrev or hasNext then
        local page = ItemTextGetPage and ItemTextGetPage() or 1
        local totalPages = ItemTextGetNumPages and ItemTextGetNumPages() or 1
        frame.pageText:SetText(string.format("Страница %d из %d", page, totalPages))
        frame.pageText:Show()
    else
        frame.pageText:Hide()
    end
    
    -- Показываем фрейм
    frame:Show()
    
    -- Скрываем стандартный
    if ItemTextFrame then
        ItemTextFrame:Hide()
    end
end

-- Переопределяем функции
local function OverrideItemTextFunctions()
    ItemTextFrame_Show = function()
        ShowCustomBook()
    end
    
    if ItemTextFrame then
        ItemTextFrame.Show = function()
            ShowCustomBook()
        end
        
        ItemTextFrame:HookScript("OnShow", function()
            ShowCustomBook()
        end)
    end
    
    print("|cff00ff00DialogUI: Функции книги переопределены|r")
end

-- Вызываем немедленно
OverrideItemTextFunctions()

-- И через события
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("VARIABLES_LOADED")

f:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == "Blizzard_ItemText" or arg1 == addonName then
            OverrideItemTextFunctions()
        end
    elseif event == "VARIABLES_LOADED" then
        OverrideItemTextFunctions()
    end
end)

-- API
addon.BookFrame = {
    Show = function(title, text) 
        local frame = CreateBookFrame()
        frame.titleText:SetText(title or "Книга")
        frame.bodyText:SetText(CleanText(text or ""))
        local textHeight = frame.bodyText:GetStringHeight()
        frame.contentFrame:SetHeight(math.max(textHeight + 20, TEXT_AREA_HEIGHT))
        frame.prevButton:Hide()
        frame.nextButton:Hide()
        frame.pageText:Hide()
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
    end
}