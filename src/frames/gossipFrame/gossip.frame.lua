---@diagnostic disable: undefined-global
NUMGOSSIPBUTTONS = 32;

local COLORS = {
    DarkBrown = {0.19, 0.17, 0.13},
    LightBrown = {0.50, 0.36, 0.24},
    Ivory = {0.87, 0.86, 0.75}
};

local savedGossipQuests = {
    available = {},
    active = {},
    text = ""
}

local totalGossipButtons = 0
local talentWipePending = false
local binderPending = false
local gossipCloseTimer = nil

-- Константы для структуры данных с значениями по умолчанию
local GOSSIP_AVAILABLE_FIELDS = 2;  -- title, level, isTrivial, isDaily, isRepeatable
local GOSSIP_ACTIVE_FIELDS = 2;    -- Будет определено динамически
local GOSSIP_OPTIONS_FIELDS = 2;     -- text, type

local gossipOpenTime = 0
local GOSSIP_MIN_OPEN_TIME = 0.5 -- Минимальное время в секундах перед закрытием

-- ИСПРАВЛЕНО: Флаг для отслеживания QUEST_GREETING
local questGreetingPending = false
local questGreetingTimer = nil

-- Функция для определения количества полей в активных квестах
local function DetermineActiveQuestFields()
    -- Если уже определено, возвращаем сохраненное значение
    if GOSSIP_ACTIVE_FIELDS then
        return GOSSIP_ACTIVE_FIELDS;
    end
    
    -- Пробуем получить тестовые данные
    local testQuests = {GetGossipActiveQuests()};
    local testSize = table.getn(testQuests);
    
    if testSize > 0 then
        -- Пробуем разные варианты
        if testSize % 4 == 0 then
            GOSSIP_ACTIVE_FIELDS = 4;  -- Стандартный формат
        elseif testSize % 3 == 0 then
            GOSSIP_ACTIVE_FIELDS = 3;  -- Альтернативный формат
        elseif testSize % 2 == 0 then
            GOSSIP_ACTIVE_FIELDS = 2;  -- Упрощенный формат (только название и уровень)
        else
            GOSSIP_ACTIVE_FIELDS = 4;  -- По умолчанию
        end
    else
        GOSSIP_ACTIVE_FIELDS = 4;  -- Значение по умолчанию
    end
    
    return GOSSIP_ACTIVE_FIELDS;
end

-- Функция для сброса определения полей (можно вызывать при необходимости)
local function ResetActiveQuestFields()
    GOSSIP_ACTIVE_FIELDS = nil;
end

-- ИСПРАВЛЕНО: Функция проверки, имеет ли NPC квесты через QUEST_GREETING
local function HasQuestGreetingQuests()
    -- Проверяем стандартные API приветствия
    local numActive = GetNumActiveQuests();
    local numAvailable = GetNumAvailableQuests();
    
    if numActive > 0 or numAvailable > 0 then
        return true;
    end
    
    return false;
end

-- ИСПРАВЛЕНО: Функция проверки, является ли NPC тренером или другим специальным типом
-- который использует QUEST_GREETING вместо GOSSIP_SHOW для квестов
local function IsSpecialQuestNPC()
    -- Получаем gossip опции
    local gossipOptions = {GetGossipOptions()};
    local numOptions = 0;
    
    if GOSSIP_OPTIONS_FIELDS and table.getn(gossipOptions) > 0 then
        numOptions = math.floor(table.getn(gossipOptions) / GOSSIP_OPTIONS_FIELDS);
    end
    
    -- Если есть только одна опция и это "trainer" или "unlearn",
    -- то это тренер с QUEST_GREETING квестами
    if numOptions == 1 then
        local optionType = gossipOptions[2]; -- тип второго элемента в паре (text, type)
        if optionType == "trainer" or optionType == "unlearn" or optionType == "battlemaster" then
            return true;
        end
    end
    
    -- Проверяем gossip текст - если он пустой или стандартный для тренера
    local gossipText = GetGossipText();
    if gossipText and (gossipText == "" or string.find(string.lower(gossipText), "i can instruct you")) then
        return true;
    end
    
    return false;
end

function SetFontColor(fontObject, key)
    local color = COLORS[key];
    if color then
        fontObject:SetTextColor(color[1], color[2], color[3]);
    end
end

function HideDefaultFrames()
    if GossipFrame and GossipFrame:IsVisible() then
        GossipFrame:Hide()
        GossipFrame:SetAlpha(0)
        GossipFrame:ClearAllPoints()
        GossipFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -5000, -5000)
    end

    if GossipFrameGreetingPanel then 
        GossipFrameGreetingPanel:Hide()
        GossipFrameGreetingPanel:SetAlpha(0)
    end
    if GossipNpcNameFrame then 
        GossipNpcNameFrame:Hide()
        GossipNpcNameFrame:SetAlpha(0)
    end
    if GossipFrameCloseButton then 
        GossipFrameCloseButton:Hide()
        GossipFrameCloseButton:SetAlpha(0)
    end
    if GossipFramePortrait then 
        GossipFramePortrait:Hide()
        GossipFramePortrait:SetTexture()
        GossipFramePortrait:SetAlpha(0)
    end
end

function DGossipFrame_OnLoad()
    HideDefaultFrames()
	
	CreateGossipButtons()

    this:RegisterEvent("GOSSIP_SHOW");
    this:RegisterEvent("GOSSIP_CLOSED");
    this:RegisterEvent("VARIABLES_LOADED");
    this:RegisterEvent("CONFIRM_TALENT_WIPE");
    this:RegisterEvent("CONFIRM_BINDER");
    this:RegisterEvent("GOSSIP_CONFIRM");
    
    -- ИСПРАВЛЕНО: Регистрируем QUEST_GREETING для обработки конфликтов
    this:RegisterEvent("QUEST_GREETING");

    this:SetMovable(true);
    this:EnableMouse(true);

    if not DGossipKeyFrame then
        CreateFrame("Frame", "DGossipKeyFrame", UIParent)
        DGossipKeyFrame:SetScript("OnKeyDown", DGossipFrame_OnKeyDown)
        DGossipKeyFrame:EnableKeyboard(false)
        DGossipKeyFrame:SetToplevel(true)
        DGossipKeyFrame:SetAllPoints(UIParent)
        DGossipKeyFrame:SetFrameStrata("TOOLTIP")
    end

    if GossipFrame then
        GossipFrame:UnregisterEvent("GOSSIP_SHOW")
        GossipFrame:UnregisterEvent("GOSSIP_CLOSED")
    end
end

function DGossipFrame_OnEvent()
    if not DGossipFrame then
        return;
    end

    if (event == "VARIABLES_LOADED") then
        if DialogUI_LoadPosition then
            DialogUI_LoadPosition(DGossipFrame);
        end
        if DialogUI_LoadConfig then
            DialogUI_LoadConfig();
        end
        if GossipFrame then
            GossipFrame:UnregisterEvent("GOSSIP_SHOW")
            GossipFrame:UnregisterEvent("GOSSIP_CLOSED")
        end
        return;
    end

    if (event == "CONFIRM_TALENT_WIPE") then
        talentWipePending = true
        return;
    end

    if (event == "CONFIRM_BINDER") then
        binderPending = true
        return;
    end

    if (event == "GOSSIP_CONFIRM") then
        return;
    end

    if (event == "QUEST_GREETING") then
        DEFAULT_CHAT_FRAME:AddMessage("DEBUG: QUEST_GREETING received in DGossipFrame");
        
        if DGossipFrame:IsVisible() then
            HideUIPanel(DGossipFrame);
        end
        
        if DQuestFrame then
            ShowUIPanel(DQuestFrame);
            if DQuestFrameGreetingPanel then
                DQuestFrameGreetingPanel:Show();
            end
            if DQuestFrame_SetPortrait then
                DQuestFrame_SetPortrait();
            end
        end
        
        return;
    end

    if (event == "GOSSIP_CLOSED") then
        gossipOpenTime = 0
        
        if gossipCloseTimer then
            gossipCloseTimer:Hide()
            gossipCloseTimer:SetScript("OnUpdate", nil)
            gossipCloseTimer = nil
        end
        
        questGreetingPending = false
        if questGreetingTimer then
            questGreetingTimer:Hide()
            questGreetingTimer:SetScript("OnUpdate", nil)
            questGreetingTimer = nil
        end
        
        if DGossipFrame:IsVisible() then
            HideUIPanel(DGossipFrame)
        end
        
        if DGossipKeyFrame then
            DGossipKeyFrame:EnableKeyboard(false)
        end
        
        talentWipePending = false
        binderPending = false
        
        return;
    end

    if (event == "GOSSIP_SHOW") then
        -- ИСПРАВЛЕНО: Получаем данные несколькими способами для надежности
        local availableQuests = {GetGossipAvailableQuests()};
        local activeQuests = {GetGossipActiveQuests()};
        local gossipOptions = {GetGossipOptions()};
        
        local numAvailable = GetNumGossipAvailableQuests();
        local numActive = GetNumGossipActiveQuests();
        
        -- Вычисляем количество из данных если API вернул 0
        local availCount = table.getn(availableQuests);
        local activeCount = table.getn(activeQuests);
        
        if numAvailable == 0 and availCount > 0 then
            if availCount % 5 == 0 then
                numAvailable = availCount / 5;
            elseif availCount % 4 == 0 then
                numAvailable = availCount / 4;
            elseif availCount % 3 == 0 then
                numAvailable = availCount / 3;
            elseif availCount % 2 == 0 then
                numAvailable = availCount / 2;
            else
                numAvailable = 1;
            end
        end
        
        if numActive == 0 and activeCount > 0 then
            if activeCount % 4 == 0 then
                numActive = activeCount / 4;
            elseif activeCount % 3 == 0 then
                numActive = activeCount / 3;
            elseif activeCount % 2 == 0 then
                numActive = activeCount / 2;
            else
                numActive = 1;
            end
        end
        
        -- ИСПРАВЛЕНО: Правильно вычисляем количество опций
        local numOptions = 0;
        local optionsCount = table.getn(gossipOptions);
        -- Каждая опция состоит из 2 элементов: текст и тип
        if optionsCount > 0 then
            numOptions = math.floor(optionsCount / 2);
        end
        
        -- ИСПРАВЛЕНО: Если GetGossipOptions вернул пусто, пробуем другие методы
        -- Иногда в 3.3.5 опции могут быть доступны через другие API
        if numOptions == 0 then
            -- Проверяем, есть ли текст gossip - если есть, значит окно должно быть
            local gossipText = GetGossipText();
            if gossipText and gossipText ~= "" then
                -- Проверяем стандартное окно - если оно есть опции, используем их
                if GossipFrame and GossipFrameGreetingPanel then
                    -- Пытаемся получить опции из стандартного фрейма
                    local standardOptions = {};
                    for i = 1, 32 do
                        local button = getglobal("GossipTitleButton" .. i);
                        if button and button:IsVisible() and button:GetText() then
                            local text = button:GetText();
                            local iconType = "gossip";
                            -- Определяем тип по тексту или иконке
                            if button.type then
                                iconType = button.type;
                            end
                            table.insert(standardOptions, text);
                            table.insert(standardOptions, iconType);
                            numOptions = numOptions + 1;
                        end
                    end
                    
                    if numOptions > 0 then
                        gossipOptions = standardOptions;
                        DEFAULT_CHAT_FRAME:AddMessage(string.format("DEBUG: Got %d options from standard frame", numOptions));
                    end
                end
            end
        end

        DEFAULT_CHAT_FRAME:AddMessage(string.format("DEBUG: GOSSIP_SHOW - numActive=%d, numAvailable=%d, numOptions=%d (raw=%d)", 
            numActive, numAvailable, numOptions, optionsCount));

        -- ИСПРАВЛЕНО: Показываем окно если есть что-либо (квесты ИЛИ опции ИЛИ просто текст)
        local gossipText = GetGossipText();
        local hasContent = (numActive > 0) or (numAvailable > 0) or (numOptions > 0) or 
                          (gossipText and gossipText ~= "");
        
        if hasContent then
            -- Сохраняем данные
            savedGossipQuests.available = availableQuests
            savedGossipQuests.active = activeQuests
            savedGossipQuests.text = gossipText
            savedGossipQuests.numAvailable = numAvailable
            savedGossipQuests.numActive = numActive
            
            DEFAULT_CHAT_FRAME:AddMessage("DEBUG: Showing DGossipFrame");
            DGossipFrame_ShowGossipWindow(availableQuests, activeQuests, gossipOptions);
        else
            DEFAULT_CHAT_FRAME:AddMessage("DEBUG: Nothing to show");
        end
        
        return;
    end
end

-- ИСПРАВЛЕНО: Вынесено в отдельную функцию для повторного использования
-- ИСПРАВЛЕНО: Вынесено в отдельную функцию для повторного использования
function DGossipFrame_ShowGossipWindow(availableQuests, activeQuests, gossipOptions)
    -- Всегда обновляем время открытия при новом GOSSIP_SHOW
    gossipOpenTime = GetTime()
    
    -- Отменяем любой таймер закрытия
    if gossipCloseTimer then
        gossipCloseTimer:Hide()
        gossipCloseTimer:SetScript("OnUpdate", nil)
        gossipCloseTimer = nil
    end
    
    -- Усиленное скрытие стандартного окна
    HideDefaultFrames()

    -- Показываем DGossipFrame
    if not DGossipFrame:IsVisible() then
        ShowUIPanel(DGossipFrame);
    end

    -- Обновляем содержимое
    DGossipFrameUpdate(availableQuests, activeQuests, gossipOptions);

    if DialogUI_ApplyAlpha then
        DialogUI_ApplyAlpha();
    end

    DGossipKeyFrame:EnableKeyboard(true)
    talentWipePending = false
    binderPending = false
end

function DGossipFrameUpdate(availableQuests, activeQuests, gossipOptions)
    availableQuests = availableQuests or {}
    activeQuests = activeQuests or {}
    gossipOptions = gossipOptions or {}
    
    local availCount = table.getn(availableQuests)
    local activeCount = table.getn(activeQuests)
    local optionsCount = table.getn(gossipOptions)
    
    DEFAULT_CHAT_FRAME:AddMessage(string.format("DEBUG: DGossipFrameUpdate - avail=%d, active=%d, options=%d", 
        availCount, activeCount, optionsCount))
    
    -- Очищаем кнопки
    for i = 1, NUMGOSSIPBUTTONS do
        local button = getglobal("DGossipTitleButton" .. i)
        if button then
            button:Hide()
            button:SetText("")
            button.type = nil
            button.isGossip = nil
            local icon = getglobal(button:GetName() .. "GossipIcon")
            if icon then
                icon:Hide()
            end
        end
    end
    
    DGossipFrame.buttonIndex = 1
    
    -- Обновляем данные
    local greetingText = getglobal("DGossipGreetingText")
    if greetingText then
        greetingText:SetText(GetGossipText() or "")
    end
    
    local nameText = getglobal("DGossipFrameNpcNameText")
    if nameText and UnitExists("npc") then
        nameText:SetText(UnitName("npc"))
    end
    
    if DGossipFramePortrait and UnitExists("npc") then
        SetPortraitTexture(DGossipFramePortrait, "npc")
    end
    
    -- ИСПРАВЛЕНО: Показываем и квесты, и опции!
    -- Сначала активные квесты
    if activeCount > 0 then
        DGossipFrameActiveQuestsUpdate(activeQuests);
    end
    
    -- Потом доступные квесты
    if availCount > 0 then
        DGossipFrameAvailableQuestsUpdate(availableQuests);
    end
    
    -- Потом опции
    if optionsCount > 0 then
        DGossipFrameOptionsUpdate(gossipOptions);
    end
    
    if DGossipFrameGreetingPanel then
        DGossipFrameGreetingPanel:Show()
    end
    
    -- Обновляем скролл
    local scrollFrame = getglobal("DGossipGreetingScrollFrame")
    if scrollFrame then
        scrollFrame:UpdateScrollChildRect()
        scrollFrame:SetVerticalScroll(0)
    end
    
    DEFAULT_CHAT_FRAME:AddMessage(string.format("DEBUG: DGossipFrameUpdate finished, final buttonIndex=%d", DGossipFrame.buttonIndex))
end


function DGossipFrame_OnKeyDown()
    local key = arg1

    local movementKeys = {
        W = true, A = true, S = true, D = true,
        UP = true, DOWN = true, LEFT = true, RIGHT = true,
        SPACE = true, NUMPAD1 = true, NUMPAD2 = true, NUMPAD3 = true,
        NUMPAD4 = true, NUMPAD6 = true, NUMPAD7 = true, NUMPAD8 = true, NUMPAD9 = true
    }
    
    if movementKeys[key] then
        DGossipKeyFrame:EnableKeyboard(false)
        local reEnableTime = GetTime() + 0.05
        DGossipKeyFrame:SetScript("OnUpdate", function()
            if GetTime() >= reEnableTime then
                if DGossipFrame:IsVisible() then
                    DGossipKeyFrame:EnableKeyboard(true)
                end
                DGossipKeyFrame:SetScript("OnUpdate", nil)
            end
        end)
        return
    end

    if key == "ESCAPE" then
        CloseGossip()
        return
    end

    if key == "SPACE" then
        DGossipSelectOption(1)
        return
    end

    if key >= "1" and key <= "9" then
        local buttonIndex = tonumber(key)
        DGossipSelectOption(buttonIndex)
        return
    end

    DGossipKeyFrame:EnableKeyboard(false)

    local reEnableTime = GetTime() + 0.05
    DGossipKeyFrame:SetScript("OnUpdate", function()
        if GetTime() >= reEnableTime then
            if DGossipFrame:IsVisible() then
                DGossipKeyFrame:EnableKeyboard(true)
            end
            DGossipKeyFrame:SetScript("OnUpdate", nil)
        end
    end)
end

function DGossipSelectOption(buttonIndex)
    if not DGossipFrame:IsVisible() then
        return
    end

    for i = 1, NUMGOSSIPBUTTONS do
        local titleButton = getglobal("DGossipTitleButton" .. i)
        if titleButton and titleButton:IsVisible() and titleButton:GetText() and titleButton:GetText() ~= "" then
            local buttonText = titleButton:GetText()
            local _, _, numStr = string.find(buttonText, "^(%d+)%.")
            if numStr then
                local displayNum = tonumber(numStr)
                if displayNum == buttonIndex then
                    DGossipTitleButton_OnClick_Direct(titleButton)
                    return
                end
            end
        end
    end
end

function DGossipFrame_OnMouseDown()
    if (arg1 == "LeftButton") then
        this:StartMoving();
    end
end

function DGossipFrame_OnMouseUp()
    this:StopMovingOrSizing();
    DialogUI_SavePosition();
    if DQuestFrame then
        DialogUI_LoadPosition(DQuestFrame);
    end
end

function DGossipTitleButton_OnClick_Direct(button)
    if not button then return end

    local buttonType = button.type
    local buttonID = button:GetID()
    local isGossip = button.isGossip

    DEFAULT_CHAT_FRAME:AddMessage(string.format("DEBUG: DGossipTitleButton_OnClick_Direct - type=%s, ID=%d, isGossip=%s, specialType=%s", 
        tostring(buttonType), buttonID, tostring(isGossip), tostring(button.specialType)));

    -- Обработка кнопки "Пока"
    if button.specialType == "goodbye" then
        CloseGossip();
        return;
    end

    -- ИСПРАВЛЕНО: Для gossip-квестов (isGossip=true) используем SelectGossip*
    if isGossip then
        if buttonType == "available" then
            DEFAULT_CHAT_FRAME:AddMessage(string.format("DEBUG: Selecting Gossip Available Quest %d", buttonID));
            SelectGossipAvailableQuest(buttonID);
            return
        elseif buttonType == "active" then
            DEFAULT_CHAT_FRAME:AddMessage(string.format("DEBUG: Selecting Gossip Active Quest %d", buttonID));
            SelectGossipActiveQuest(buttonID);
            return
        end
    end

    -- Для обычных gossip опций (не квесты)
    if buttonType == "gossip" then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("DEBUG: Selecting Gossip Option %d", buttonID));
        SelectGossipOption(buttonID);
        return
    end

    DEFAULT_CHAT_FRAME:AddMessage("DEBUG: ERROR - Unknown button type: " .. tostring(buttonType));
end

function DGossipTitleButton_OnClick()
    DGossipTitleButton_OnClick_Direct(this)
end

function DGossipFrameOptionsUpdate(optionsTable)
    if not optionsTable or table.getn(optionsTable) == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("DEBUG: OptionsUpdate - empty table")
        return;
    end
	
    local titleButton;
    local titleIndex = 1;
    local optionsCount = table.getn(optionsTable);
    local numOptions = math.floor(optionsCount / 2);

    DEFAULT_CHAT_FRAME:AddMessage(string.format("DEBUG: OptionsUpdate - numOptions=%d, raw=%d", numOptions, optionsCount))

    if numOptions == 0 then return end

    for i = 1, numOptions do
        local baseIndex = (i - 1) * 2 + 1
        local text = optionsTable[baseIndex];
        local iconType = optionsTable[baseIndex + 1];

        if not text then
            DEFAULT_CHAT_FRAME:AddMessage(string.format("DEBUG: No text for option %d", i))
            break;
        end

        if (DGossipFrame.buttonIndex > NUMGOSSIPBUTTONS) then
            if not DGossipFrame.optionsLimitReached then
                DGossipFrame.optionsLimitReached = true
                DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[DialogUI]|r Этот NPC имеет слишком много опций диалога. Отображаются только первые " .. NUMGOSSIPBUTTONS .. " опций.", 1, 0.5, 0)
            end
            break;
        end

        titleButton = getglobal("DGossipTitleButton" .. DGossipFrame.buttonIndex);
        
        if not titleButton then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[DialogUI]|r Ошибка: не удалось создать кнопку диалога #" .. DGossipFrame.buttonIndex, 1, 0, 0)
            break;
        end

        local numberedText = DGossipFrame.buttonIndex .. ". " .. text
        titleButton:SetText(numberedText);
        totalGossipButtons = totalGossipButtons + 1

        titleButton:SetID(titleIndex);
        titleButton.type = "gossip";
        titleButton.specialType = iconType;
        titleButton.isGossip = false; -- Это не квест, а gossip опция

        -- Переопределяем обработчик OnClick для gossip кнопок
        titleButton:SetScript("OnClick", function()
            DGossipTitleButton_OnClick_Direct(this)
        end)

        -- ИСПРАВЛЕНО: Используем существующую иконку из XML
        local gossipIcon = _G[titleButton:GetName() .. "QuestIcon"]
        if not gossipIcon then
            -- Если иконки нет по имени, создаем новую (только для опций, так как у них нет иконки в XML)
            gossipIcon = titleButton:CreateTexture(titleButton:GetName() .. "GossipIcon", "OVERLAY")
        end
        
        if gossipIcon then
            gossipIcon:SetWidth(24)
            gossipIcon:SetHeight(24)
            gossipIcon:SetPoint("LEFT", titleButton, "LEFT", 5, 0)
            gossipIcon:SetDrawLayer("OVERLAY")

            -- Для "goodbye" используем специальную иконку, для "vendor" тоже
            local texturePath;
            if iconType == "goodbye" or iconType == "bye" then
                texturePath = "Interface/AddOns/DialogUI/src/assets/art/icons/gossipIcon"
            elseif iconType == "vendor" then
                texturePath = "Interface/AddOns/DialogUI/src/assets/art/icons/vendorGossipIcon"
            else
                texturePath = DialogUI_GetGossipIconPath(iconType, text)
            end
            
            gossipIcon:SetTexture(texturePath)
            gossipIcon:Show()
        end

        titleButton:SetNormalTexture("Interface/AddOns/DialogUI/src/assets/art/parchment/OptionBackground-common")
        titleButton:SetNormalFontObject("DQuestButtonTitleGossip")
        titleButton:SetHeight(titleButton:GetTextHeight() + 20)
        
        local buttonText = titleButton:GetFontString()
        if buttonText then
            buttonText:ClearAllPoints()
            buttonText:SetPoint("LEFT", titleButton, "LEFT", 35, 0)
        end

        titleButton:Show()
        
        DGossipFrame.buttonIndex = DGossipFrame.buttonIndex + 1;
        titleIndex = titleIndex + 1;
    end
    
    DEFAULT_CHAT_FRAME:AddMessage(string.format("DEBUG: OptionsUpdate finished - buttonIndex now %d", DGossipFrame.buttonIndex))
end

function DGossipFrameAvailableQuestsUpdate(questsTable)
    if not questsTable or table.getn(questsTable) == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("DEBUG: AvailableQuestsUpdate - empty table")
        return;
    end

    local dataSize = table.getn(questsTable)
    
    -- Правильное определение количества полей
    local fieldsPerQuest = 5
    if dataSize % 5 == 0 then
        fieldsPerQuest = 5
    elseif dataSize % 4 == 0 then
        fieldsPerQuest = 4
    elseif dataSize % 3 == 0 then
        fieldsPerQuest = 3
    elseif dataSize % 2 == 0 then
        fieldsPerQuest = 2
    else
        fieldsPerQuest = 1
    end
    
    local numQuests = math.floor(dataSize / fieldsPerQuest)

    DEFAULT_CHAT_FRAME:AddMessage(string.format("DEBUG: AvailableQuestsUpdate - dataSize=%d, fieldsPerQuest=%d, numQuests=%d", 
        dataSize, fieldsPerQuest, numQuests))

    if numQuests == 0 then return end

    local titleIndex = 1

    for i = 1, numQuests do
        if DGossipFrame.buttonIndex > NUMGOSSIPBUTTONS then break end
        
        local titleButton = getglobal("DGossipTitleButton" .. DGossipFrame.buttonIndex);
        if not titleButton then break end
        
        local baseIndex = (i - 1) * fieldsPerQuest + 1
        local questTitle = questsTable[baseIndex]
        local questLevel = questsTable[baseIndex + 1]
        local isTrivial = questsTable[baseIndex + 2]
        local isDaily = questsTable[baseIndex + 3]
        local isRepeatable = questsTable[baseIndex + 4]

        DEFAULT_CHAT_FRAME:AddMessage(string.format("DEBUG: Quest %d - title=%s, level=%s", 
            i, tostring(questTitle), tostring(questLevel)))

        if not questTitle or questTitle == "" then break end

        local displayText = DGossipFrame.buttonIndex .. ". " .. questTitle
        
        titleButton:SetText(displayText);
        titleButton:SetID(titleIndex);
        titleButton.type = "available"
        titleButton.questIndex = titleIndex
        titleButton.isGossip = true
        titleButton.isTrivial = isTrivial
        titleButton.isDaily = isDaily
        titleButton.isRepeatable = isRepeatable

        titleButton:SetScript("OnClick", function()
            DGossipTitleButton_OnClick_Direct(this)
        end)

        -- ИСПРАВЛЕНО: Используем существующую иконку из XML вместо создания новой
        local gossipIcon = _G[titleButton:GetName() .. "QuestIcon"]
        if not gossipIcon then
            -- Если иконки нет по имени, ищем через GetRegions
            local regions = {titleButton:GetRegions()}
            for _, region in ipairs(regions) do
                if region:GetObjectType() == "Texture" then
                    gossipIcon = region
                    break
                end
            end
        end
        
        if gossipIcon then
            gossipIcon:SetWidth(24)
            gossipIcon:SetHeight(24)
            gossipIcon:SetPoint("LEFT", titleButton, "LEFT", 5, 0)
            gossipIcon:SetTexture("Interface\\AddOns\\DialogUI\\src\\assets\\art\\icons\\availableQuestIcon")
            gossipIcon:Show()
        end

        -- Настройка кнопки
        titleButton:SetNormalTexture("Interface/AddOns/DialogUI/src/assets/art/parchment/OptionBackground-common")
        titleButton:SetHeight(40)
        
        local btnText = titleButton:GetFontString()
        if btnText then
            btnText:ClearAllPoints()
            btnText:SetPoint("LEFT", titleButton, "LEFT", 35, 0)
        end

        titleButton:Show()
        
        DEFAULT_CHAT_FRAME:AddMessage(string.format("DEBUG: Button %d ready - isGossip=%s, ID=%d", 
            DGossipFrame.buttonIndex, tostring(titleButton.isGossip), titleIndex))
        
        DGossipFrame.buttonIndex = DGossipFrame.buttonIndex + 1;
        titleIndex = titleIndex + 1
    end
end

function DGossipFrameActiveQuestsUpdate(questsTable)
    if not questsTable or table.getn(questsTable) == 0 then return end

    local dataSize = table.getn(questsTable)
    
    -- Правильное определение количества полей
    local fieldsPerQuest = 4
    if dataSize % 4 == 0 then
        fieldsPerQuest = 4
    elseif dataSize % 3 == 0 then
        fieldsPerQuest = 3
    elseif dataSize % 2 == 0 then
        fieldsPerQuest = 2
    else
        fieldsPerQuest = 1
    end
    
    local numQuests = math.floor(dataSize / fieldsPerQuest)

    if numQuests == 0 then return end

    local titleIndex = 1

    for i = 1, numQuests do
        if DGossipFrame.buttonIndex > NUMGOSSIPBUTTONS then break end
        
        local titleButton = getglobal("DGossipTitleButton" .. DGossipFrame.buttonIndex);
        if not titleButton then break end
        
        local baseIndex = (i - 1) * fieldsPerQuest + 1
        local questTitle = questsTable[baseIndex]
        local questLevel = questsTable[baseIndex + 1]
        local isComplete = questsTable[baseIndex + 2]
        local isDaily = questsTable[baseIndex + 3]

        if not questTitle or questTitle == "" then break end

        local displayText = DGossipFrame.buttonIndex .. ". " .. questTitle
        
        titleButton:SetText(displayText);
        titleButton:SetID(titleIndex);
        titleButton.type = "active"
        titleButton.questIndex = titleIndex
        titleButton.isGossip = true
        titleButton.isComplete = isComplete
        titleButton.isDaily = isDaily

        titleButton:SetScript("OnClick", function()
            DGossipTitleButton_OnClick_Direct(this)
        end)

        -- ИСПРАВЛЕНО: Используем существующую иконку из XML вместо создания новой
        local gossipIcon = _G[titleButton:GetName() .. "QuestIcon"]
        if not gossipIcon then
            -- Если иконки нет по имени, ищем через GetRegions (как запасной вариант)
            local regions = {titleButton:GetRegions()}
            for _, region in ipairs(regions) do
                if region:GetObjectType() == "Texture" then
                    gossipIcon = region
                    break
                end
            end
        end
        
        if gossipIcon then
            gossipIcon:SetWidth(24)
            gossipIcon:SetHeight(24)
            gossipIcon:SetPoint("LEFT", titleButton, "LEFT", 5, 0)
            
            if isComplete then
                gossipIcon:SetTexture("Interface\\AddOns\\DialogUI\\src\\assets\\art\\icons\\completeQuestIcon")
            else
                gossipIcon:SetTexture("Interface\\AddOns\\DialogUI\\src\\assets\\art\\icons\\incompleteQuestIcon")
            end
            gossipIcon:Show()
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[DialogUI] Warning: Could not find icon for button " .. DGossipFrame.buttonIndex)
        end

        -- Настройка кнопки
        titleButton:SetNormalTexture("Interface/AddOns/DialogUI/src/assets/art/parchment/OptionBackground-common")
        titleButton:SetHeight(40)
        
        local btnText = titleButton:GetFontString()
        if btnText then
            btnText:ClearAllPoints()
            btnText:SetPoint("LEFT", titleButton, "LEFT", 35, 0)
        end

        titleButton:Show()
        
        DEFAULT_CHAT_FRAME:AddMessage(string.format("DEBUG: Button %d ready - isGossip=%s, ID=%d", 
            DGossipFrame.buttonIndex, tostring(titleButton.isGossip), titleIndex))
        
        DGossipFrame.buttonIndex = DGossipFrame.buttonIndex + 1;
        titleIndex = titleIndex + 1
    end
end

-- ИСПРАВЛЕНО: Функция определения типа иконки как в Storyline
function DetermineGossipIconType(gossipText)
    local text = string.lower(gossipText)
    
    -- Профессии
    local professions = {
        "alchemy", "blacksmithing", "enchanting", "engineering", 
        "herbalism", "leatherworking", "mining", "skinning", 
        "tailoring", "jewelcrafting", "inscription", "cooking", "fishing", "first aid"
    }
    
    for _, profession in pairs(professions) do
        if string.find(text, profession) then
            return profession
        end
    end
    
    -- Классы
    local classes = {
        "warrior", "paladin", "hunter", "rogue", "priest", 
        "shaman", "mage", "warlock", "druid", "death knight"
    }
    
    for _, class in pairs(classes) do
        if string.find(text, class) then
            return class
        end
    end
    
    -- Специальные случаи
    if string.find(text, "profession") and string.find(text, "trainer") then
        return "professionTrainer"
    elseif string.find(text, "class") and string.find(text, "trainer") then
        return "classTrainer"
    elseif string.find(text, "stable") then
        return "stablemaster"
    elseif string.find(text, "inn") then
        return "innkeeper"
    elseif string.find(text, "mailbox") then
        return "mailbox"
    elseif string.find(text, "guild master") then
        return "guildMaster"
    elseif string.find(text, "trainer") and string.find(text, "pet") then
        return "pettrainer"
    elseif string.find(text, "auction") then
        return "auctionHouse"
    elseif string.find(text, "weapon") and string.find(text, "trainer") then
        return "weaponsTrainer"
    elseif string.find(text, "deeprun") then
        return "deeprunTram"
    elseif string.find(text, "bat handler") or 
           string.find(text, "wind rider master") or 
           string.find(text, "gryphon master") or 
           string.find(text, "hippogryph master") or 
           string.find(text, "flight master") then
        return "flight"
    elseif string.find(text, "bank") then
        return "banker"
    else
        return "gossip"
    end
end

-- ИСПРАВЛЕНО: Новая функция для определения пути к иконке
function DialogUI_GetGossipIconPath(iconType, gossipText)
    local texturePath
    
    -- ИСПРАВЛЕНО: Добавлена обработка vendor
    if iconType == "vendor" then
        texturePath = "Interface/AddOns/DialogUI/src/assets/art/icons/vendorGossipIcon"
    elseif iconType == "trainer" then
        texturePath = "Interface/AddOns/DialogUI/src/assets/art/icons/trainerGossipIcon"
    elseif iconType == "gossip" then
        local specificType = DetermineGossipIconType(gossipText)
        texturePath = "Interface/AddOns/DialogUI/src/assets/art/icons/" .. specificType .. "GossipIcon"
    elseif iconType == "banker" then
        texturePath = "Interface/AddOns/DialogUI/src/assets/art/icons/bankerGossipIcon"
    elseif iconType == "battlemaster" then
        texturePath = "Interface/AddOns/DialogUI/src/assets/art/icons/battlemasterGossipIcon"
    elseif iconType == "binder" then
        texturePath = "Interface/AddOns/DialogUI/src/assets/art/icons/binderGossipIcon"
    elseif iconType == "taxi" then
        texturePath = "Interface/AddOns/DialogUI/src/assets/art/icons/flightGossipIcon"
    elseif iconType == "unlearn" then
        texturePath = "Interface/AddOns/DialogUI/src/assets/art/icons/unlearnGossipIcon"
    elseif iconType == "tabard" then
        texturePath = "Interface/AddOns/DialogUI/src/assets/art/icons/guildMasterGossipIcon"
    elseif iconType == "auctionHouse" then
        texturePath = "Interface/AddOns/DialogUI/src/assets/art/icons/auctionHouseGossipIcon"
    else
        -- Маппинг для других типов
        local iconMap = {
            ["alchemy"] = "alchemyGossipIcon",
            ["blacksmithing"] = "blacksmithingGossipIcon",
            ["enchanting"] = "enchantingGossipIcon",
            ["engineering"] = "engineeringGossipIcon",
            ["herbalism"] = "herbalismGossipIcon",
            ["leatherworking"] = "leatherworkingGossipIcon",
            ["mining"] = "miningGossipIcon",
            ["skinning"] = "skinningGossipIcon",
            ["tailoring"] = "tailoringGossipIcon",
            ["jewelcrafting"] = "jewelcraftingGossipIcon",
            ["inscription"] = "inscriptionGossipIcon",
            ["cooking"] = "cookingGossipIcon",
            ["fishing"] = "fishingGossipIcon",
            ["first aid"] = "firstAidGossipIcon",
            ["firstAid"] = "firstAidGossipIcon",
            ["warrior"] = "warriorGossipIcon",
            ["paladin"] = "paladinGossipIcon",
            ["hunter"] = "hunterGossipIcon",
            ["rogue"] = "rogueGossipIcon",
            ["priest"] = "priestGossipIcon",
            ["shaman"] = "shamanGossipIcon",
            ["mage"] = "mageGossipIcon",
            ["warlock"] = "warlockGossipIcon",
            ["druid"] = "druidGossipIcon",
            ["death knight"] = "deathKnightGossipIcon",
            ["deathKnight"] = "deathKnightGossipIcon",
            ["stablemaster"] = "stablemasterGossipIcon",
            ["innkeeper"] = "innkeeperGossipIcon",
            ["mailbox"] = "mailboxGossipIcon",
            ["guildMaster"] = "guildMasterGossipIcon",
            ["pettrainer"] = "pettrainerGossipIcon",
            ["weaponsTrainer"] = "weaponsTrainerGossipIcon",
            ["deeprunTram"] = "deeprunTramGossipIcon",
            ["flight"] = "flightGossipIcon",
            ["professionTrainer"] = "professionTrainerGossipIcon",
            ["classTrainer"] = "classTrainerGossipIcon",
        }
        
        if iconMap[iconType] then
            texturePath = "Interface/AddOns/DialogUI/src/assets/art/icons/" .. iconMap[iconType]
        else
            texturePath = "Interface/AddOns/DialogUI/src/assets/art/icons/petitionGossipIcon"
        end
    end
    
    return texturePath
end

function ClearAllGossipIcons()
    for i = 1, NUMGOSSIPBUTTONS do
        local titleButton = getglobal("DGossipTitleButton" .. i)
        if titleButton then
            -- Пытаемся найти иконку по имени из XML
            local gossipIcon = _G[titleButton:GetName() .. "QuestIcon"]
            if gossipIcon then
                gossipIcon:Hide()
                gossipIcon:SetTexture(nil)
            end
            
            -- Также проверяем возможные созданные иконки (для опций)
            local customIcon = _G[titleButton:GetName() .. "GossipIcon"]
            if customIcon then
                customIcon:Hide()
                customIcon:SetTexture(nil)
            end
        end
    end
end

function DialogUI_SavePosition()
    if not DialogUIFramePosition then
        DialogUIFramePosition = {};
    end

    local frame = this or DGossipFrame or DQuestFrame;
    if not frame then return; end

    local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint();
    DialogUIFramePosition.point = point;
    DialogUIFramePosition.relativePoint = relativePoint;
    DialogUIFramePosition.xOfs = xOfs;
    DialogUIFramePosition.yOfs = yOfs;

    DQuestFramePosition = DialogUIFramePosition;
end

function DialogUI_LoadPosition(frame)
    local position = DialogUIFramePosition or DQuestFramePosition;

    if position and position.point and frame then
        frame:ClearAllPoints();
        frame:SetPoint(
            position.point, 
            UIParent, 
            position.relativePoint or position.point, 
            position.xOfs or 0, 
            position.yOfs or -104
        );
    end
end

function CreateGossipButtons()
    local parent = DGossipGreetingScrollChildFrame
    if not parent then return end
    
    local prevButton = _G["DGossipTitleButton1"]
    
    for i = 2, NUMGOSSIPBUTTONS do
        local buttonName = "DGossipTitleButton" .. i
        local button = _G[buttonName]
        
        if not button then
            -- Создаем новую кнопку
            button = CreateFrame("Button", buttonName, parent, "DQuestTitleButtonTemplate")
            
            -- Устанавливаем позицию относительно предыдущей кнопки
            if prevButton then
                button:SetPoint("TOPLEFT", prevButton, "BOTTOMLEFT", 0, -10)
            end
            
            -- Настраиваем размеры и текст
            button:SetHeight(24)
            button:SetWidth(400)
            
            -- ИСПРАВЛЕНО: НЕ создаем иконку здесь, она уже есть в шаблоне DQuestTitleButtonTemplate
            -- Просто находим существующую иконку
            local icon = _G[buttonName .. "QuestIcon"]
            if icon then
                icon:SetWidth(24)
                icon:SetHeight(24)
                icon:SetPoint("LEFT", button, "LEFT", 5, 0)
            end
            
            -- Настраиваем текст кнопки
            local text = button:GetFontString()
            if text then
                text:ClearAllPoints()
                text:SetPoint("LEFT", button, "LEFT", 35, 0)
            end
            
            prevButton = button
        end
    end
end