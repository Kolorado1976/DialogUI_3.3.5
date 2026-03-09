---@diagnostic disable: undefined-global

-- Система конфигурации DialogUI
DialogUI_Config = {
    scale = 1.0,        -- Масштаб фрейма (0.5 - 2.0)
    alpha = 1.0,        -- Прозрачность фрейма (0.1 - 1.0)
    fontSize = 1.0,     -- Множитель размера шрифта (0.5 - 2.0)
    fontFile = "frizqt___cyr.ttf"  -- Шрифт по умолчанию
};

-- Доступные шрифты
local AVAILABLE_FONTS = {
    { name = "Magistral", file = "frizqt___cyr.ttf" },
    { name = "PTNarrow", file = "frizqt__.ttf" },
    { name = "Arial", file = "ARIALN.ttf" },
    { name = "Expressway", file = "Expressway.ttf" }
};

local COLORS = {
    DarkBrown = {0.19, 0.17, 0.13},
    LightBrown = {0.50, 0.36, 0.24},
    Ivory = {0.87, 0.86, 0.75}
};

function SetFontColor(fontObject, key)
    local color = COLORS[key];
    if color and fontObject and fontObject.SetTextColor then
        fontObject:SetTextColor(color[1], color[2], color[3]);
    end
end

-- Функции главного окна конфигурации
function DConfigFrame_OnLoad()
    -- Запрещаем перемещение, так как окно всегда центрировано
    this:SetMovable(false);
    this:EnableMouse(true);

    -- Информационный текст с описанием доступных команд
    local infoText = "Настройка параметров интерфейса DialogUI.\n\n" ..
                    "• Масштаб: Изменение размера окон диалогов (от 0.5 до 2.0)\n" ..
                    "• Прозрачность: Настройка прозрачности фона (от 10% до 100%)\n" ..
                    "• Размер шрифта: Изменение размера текста в диалогах (от 0.5 до 2.0)\n" ..
                    "• Шрифт: Выбор шрифта для текста в диалогах\n" ..
                    "• Динамическая камера: Автоматическая настройка камеры при разговоре с NPC\n\n" ..
                    "Доступные команды:\n" ..
                    "▪ /dialogui или /dialogui config - открыть окно настроек\n" ..
                    "▪ /dialogui reset - сбросить все настройки\n" ..
                    "▪ /togglecamera или /dcamera - вкл/выкл динамическую камеру\n" ..
                    "▪ /testcamera - проверить позиционирование камеры\n" ..
                    "▪ /camerapreset [preset] - применить пресет камеры (cinematic, close, normal, wide)\n\n" ..
                    "Значения можно изменять непосредственно в полях ввода.\n" ..
                    "Все изменения применяются и сохраняются автоматически.";

    local infoTextObj = getglobal("DConfigInfoText");
    if infoTextObj then
        infoTextObj:SetText(infoText);
        SetFontColor(infoTextObj, "DarkBrown");
    end
end

function DConfigFrame_OnShow()
    PlaySound("igQuestListOpen");

    -- Всегда держим окно настроек с масштабом 1.0 и по центру
    DConfigFrame:SetScale(1.0);
    DConfigFrame:ClearAllPoints();
    DConfigFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0);

    -- Инициализация прокручиваемой области
    local scrollFrame = getglobal("DConfigScrollFrame");
    local scrollChild = getglobal("DConfigScrollChild");
    if scrollFrame and scrollChild then
        scrollFrame:SetScrollChild(scrollChild);
        scrollFrame:SetHorizontalScroll(0);
        scrollFrame:SetVerticalScroll(0);
    end

    -- Устанавливаем цвета для подписей
    local scaleLabel = getglobal("DConfigScaleLabel");
    if scaleLabel then
        SetFontColor(scaleLabel, "DarkBrown");
        scaleLabel:SetText("Масштаб:");
    end

    local alphaLabel = getglobal("DConfigAlphaLabel");
    if alphaLabel then
        SetFontColor(alphaLabel, "DarkBrown");
        alphaLabel:SetText("Прозрачность:");
    end

    local fontLabel = getglobal("DConfigFontLabel");
    if fontLabel then
        SetFontColor(fontLabel, "DarkBrown");
        fontLabel:SetText("Размер шрифта:");
    end

    local fontSelectLabel = getglobal("DConfigFontSelectLabel");
    if fontSelectLabel then
        SetFontColor(fontSelectLabel, "DarkBrown");
        fontSelectLabel:SetText("Шрифт:");
    end

    -- Обновляем значения в полях ввода
    local scaleEditBox = getglobal("DConfigScaleEditBox");
    if scaleEditBox then
        scaleEditBox:SetText(string.format("%.1f", DialogUI_Config.scale));
    end

    local alphaEditBox = getglobal("DConfigAlphaEditBox");
    if alphaEditBox then
        alphaEditBox:SetText(tostring(math.floor(DialogUI_Config.alpha * 100)));
    end

    local fontEditBox = getglobal("DConfigFontEditBox");
    if fontEditBox then
        fontEditBox:SetText(string.format("%.1f", DialogUI_Config.fontSize));
    end

    -- Обновляем кнопки выбора шрифта
    DConfigFrame_UpdateFontButtons();

    -- Применяем текущую прозрачность к фону окна настроек
    DialogUI_ApplyConfigAlpha();

    -- Добавляем элементы управления камерой ПОСЛЕ кнопок шрифтов
    if DynamicCamera and DynamicCamera.AddConfigControls then
        -- Проверяем, были ли уже созданы контролы камеры
        if not getglobal("DCameraSectionTitle") then
            -- Создаем контролы (они создадутся с привязкой по умолчанию)
            DynamicCamera:AddConfigControls();
        end
        
        -- Перемещаем существующие контролы камеры, привязывая к ПЕРВОЙ кнопке шрифта
        DialogUI_PositionCameraControls();
    end
end

function DConfigFrame_OnHide()
    PlaySound("igQuestListClose");
end

-- Функция для правильного позиционирования элементов камеры после кнопок шрифтов
function DialogUI_PositionCameraControls()
    if not DynamicCamera then return; end
    
    local cameraSection = getglobal("DCameraSectionTitle");
    if not cameraSection then return; end
    
    -- Привязываем секцию камеры к ПЕРВОЙ кнопке шрифта (DConfigFontButton1)
    cameraSection:ClearAllPoints();
    cameraSection:SetPoint("TOP", "DConfigFontButton1", "BOTTOM", 0, -70);
    -- Отступ -70 означает: 10px после второго ряда + 10px отступ + 50px дополнительно
    
    -- Перемещаем остальные элементы камеры (они обычно привязаны к заголовку)
    local cameraEnableCheck = getglobal("DCameraEnableCheck");
    if cameraEnableCheck then
        cameraEnableCheck:ClearAllPoints();
        cameraEnableCheck:SetPoint("TOP", cameraSection, "BOTTOM", 0, -10);
    end
    
    local cameraPresetLabel = getglobal("DCameraPresetLabel");
    if cameraPresetLabel then
        cameraPresetLabel:ClearAllPoints();
        cameraPresetLabel:SetPoint("TOP", cameraEnableCheck, "BOTTOM", 0, -15);
    end
    
    -- Привязываем пресеты к первой кнопке шрифта для правильного выравнивания
    local cinematicButton = getglobal("DCameraCinematicButton");
    if cinematicButton then
        cinematicButton:ClearAllPoints();
        cinematicButton:SetPoint("TOPLEFT", "DConfigFontButton1", "BOTTOMLEFT", 0, -140);
    end
    
    local closeButton = getglobal("DCameraCloseButton");
    if closeButton then
        closeButton:ClearAllPoints();
        closeButton:SetPoint("LEFT", cinematicButton, "RIGHT", 10, 0);
    end
    
    local normalButton = getglobal("DCameraNormalButton");
    if normalButton then
        normalButton:ClearAllPoints();
        normalButton:SetPoint("LEFT", closeButton, "RIGHT", 10, 0);
    end
    
    local wideButton = getglobal("DCameraWideButton");
    if wideButton then
        wideButton:ClearAllPoints();
        wideButton:SetPoint("LEFT", normalButton, "RIGHT", 10, 0);
    end
    
    -- Обновляем если есть функция обновления
    if DynamicCamera.UpdateConfigControls then
        DynamicCamera.UpdateConfigControls();
    end
    
    -- Корректируем высоту скролл-контейнера, чтобы вместить все элементы
    local scrollChild = getglobal("DConfigScrollChild");
    if scrollChild then
        -- Получаем нижнюю границу последнего элемента камеры
        local lastCameraControl = getglobal("DCameraWideButton") or getglobal("DCameraEnableCheck");
        if lastCameraControl then
            local bottom = lastCameraControl:GetBottom();
            local childTop = scrollChild:GetTop();
            if bottom and childTop then
                local requiredHeight = childTop - bottom + 50; -- +50 для отступа
                scrollChild:SetHeight(math.max(requiredHeight, 900));
            end
        end
    end
end

-- Функции полей ввода
function DConfigScaleEditBox_OnEnterPressed()
    local editBox = getglobal("DConfigScaleEditBox");
    if not editBox then return; end

    local text = editBox:GetText();
    -- Заменяем запятую на точку для поддержки десятичных чисел
    text = string.gsub(text, ",", ".");
    local value = tonumber(text);

    if value and value >= 0.5 and value <= 2.0 then
        DialogUI_Config.scale = value;
        editBox:SetText(string.format("%.1f", value));
        DialogUI_ApplyScale();
        DialogUI_SaveConfig();
        editBox:ClearFocus();
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("DialogUI: Масштаб установлен на " .. string.format("%.1f", value));
        end
    else
        editBox:SetText(string.format("%.1f", DialogUI_Config.scale));
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("DialogUI: Масштаб должен быть между 0.5 и 2.0 (пример: 1.5)");
        end
    end
end

function DConfigAlphaEditBox_OnEnterPressed()
    local editBox = getglobal("DConfigAlphaEditBox");
    if not editBox then return; end

    local value = tonumber(editBox:GetText());
    if value and value >= 10 and value <= 100 then
        local alpha = value / 100;
        DialogUI_Config.alpha = alpha;
        editBox:SetText(tostring(value));
        DialogUI_ApplyAlpha();
        DialogUI_ApplyConfigAlpha();
        DialogUI_SaveConfig();
        editBox:ClearFocus();
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("DialogUI: Прозрачность установлена на " .. value .. "%");
        end
    else
        editBox:SetText(tostring(math.floor(DialogUI_Config.alpha * 100)));
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("DialogUI: Прозрачность должна быть между 10 и 100 (только целые числа)");
        end
    end
end

function DConfigFontEditBox_OnEnterPressed()
    local editBox = getglobal("DConfigFontEditBox");
    if not editBox then return; end

    local text = editBox:GetText();
    -- Заменяем запятую на точку для поддержки десятичных чисел
    text = string.gsub(text, ",", ".");
    local value = tonumber(text);

    if value and value >= 0.5 and value <= 2.0 then
        DialogUI_Config.fontSize = value;
        editBox:SetText(string.format("%.1f", value));
        DialogUI_ApplyFontSize();
        DialogUI_SaveConfig();
        editBox:ClearFocus();
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("DialogUI: Размер шрифта установлен на " .. string.format("%.1f", value));
        end
    else
        editBox:SetText(string.format("%.1f", DialogUI_Config.fontSize));
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("DialogUI: Размер шрифта должен быть между 0.5 и 2.0 (пример: 1.2)");
        end
    end
end

-- Функции кнопок
function DConfigResetButton_OnClick()
    -- Сброс к значениям по умолчанию
    DialogUI_Config.scale = 1.0;
    DialogUI_Config.alpha = 1.0;
    DialogUI_Config.fontSize = 1.0;
    DialogUI_Config.fontFile = "frizqt___cyr.ttf";

    -- Обновляем поля ввода
    local scaleEditBox = getglobal("DConfigScaleEditBox");
    if scaleEditBox then
        scaleEditBox:SetText("1.0");
    end

    local alphaEditBox = getglobal("DConfigAlphaEditBox");
    if alphaEditBox then
        alphaEditBox:SetText("100");
    end

    local fontEditBox = getglobal("DConfigFontEditBox");
    if fontEditBox then
        fontEditBox:SetText("1.0");
    end

    -- Обновляем кнопки шрифтов
    DConfigFrame_UpdateFontButtons();

    -- Применяем изменения
    DialogUI_ApplyAllSettings();
    DialogUI_SaveConfig();

    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("DialogUI: Настройки сброшены к значениям по умолчанию");
    end
    PlaySound("igQuestListComplete");
end

function DConfigCloseButton_OnClick()
    HideUIPanel(DConfigFrame);
end

-- Функции применения конфигурации
function DialogUI_ApplyScale()
    local scale = DialogUI_Config.scale;

    -- Применяем масштаб только к окнам диалогов, НЕ к окну конфигурации
    if DQuestFrame then
        DQuestFrame:SetScale(scale);
    end
    if DGossipFrame then
        DGossipFrame:SetScale(scale);
    end
    -- Окно конфигурации сохраняет фиксированный масштаб 1.0
end

function DialogUI_ApplyAlpha()
    local alpha = DialogUI_Config.alpha;

    -- Применяем прозрачность к окну заданий и его панелям
    if DQuestFrame then
        DialogUI_ApplyAlphaToPanel(DQuestFrame, alpha);

        local rewardPanel = getglobal("DQuestFrameRewardPanel");
        if rewardPanel then
            DialogUI_ApplyAlphaToPanel(rewardPanel, alpha);
        end

        local progressPanel = getglobal("DQuestFrameProgressPanel");
        if progressPanel then
            DialogUI_ApplyAlphaToPanel(progressPanel, alpha);
        end

        local greetingPanel = getglobal("DQuestFrameGreetingPanel");
        if greetingPanel then
            DialogUI_ApplyAlphaToPanel(greetingPanel, alpha);
        end

        local detailPanel = getglobal("DQuestFrameDetailPanel");
        if detailPanel then
            DialogUI_ApplyAlphaToPanel(detailPanel, alpha);
        end
    end

    -- Применяем прозрачность к окну разговоров
    if DGossipFrame then
        DialogUI_ApplyAlphaToPanel(DGossipFrame, alpha);

        local gossipGreetingPanel = getglobal("DGossipFrameGreetingPanel");
        if gossipGreetingPanel then
            DialogUI_ApplyAlphaToPanel(gossipGreetingPanel, alpha);
        end
    end

    -- Применяем прозрачность к любым фреймам денег, которые могут существовать
    local moneyFrame = getglobal("DQuestProgressRequiredMoneyFrame");
    if moneyFrame then
        DialogUI_ApplyAlphaToPanel(moneyFrame, alpha);
    end

    -- Прозрачность окна конфигурации обрабатывается отдельно функцией DialogUI_ApplyConfigAlpha()
end

-- Вспомогательная функция для применения прозрачности к текстуре фона панели
function DialogUI_ApplyAlphaToPanel(panel, alpha)
    if not panel then return; end
    local regions = {panel:GetRegions()};
    for i = 1, table.getn(regions) do
        local region = regions[i];
        if region and region:GetObjectType() == "Texture" then
            local texturePath = region:GetTexture();
            if texturePath and string.find(texturePath, "Parchment") then
                region:SetAlpha(alpha);
                break;
            end
        end
    end
end

-- Простая версия без сохранения исходных размеров
function DialogUI_ApplyFontSize()
    local fontSize = DialogUI_Config.fontSize;
    
    -- Просто перебираем все фреймы и применяем масштаб
    -- WoW автоматически использует базовый размер шрифта из шаблона
    
    if DQuestFrame then
        -- Сначала "сбрасываем", перебирая все регионы и применяя масштаб
        -- Так как базовый размер берется из шаблона, умножение на 1.0 даст исходный размер
        DialogUI_ScaleFonts(DQuestFrame, 1.0);  -- Сброс к базовому
        DialogUI_ScaleFonts(DQuestFrame, fontSize);  -- Применение нового масштаба
    end
    
    if DGossipFrame then
        DialogUI_ScaleFonts(DGossipFrame, 1.0);  -- Сброс к базовому
        DialogUI_ScaleFonts(DGossipFrame, fontSize);  -- Применение нового масштаба
    end
end

function DialogUI_ScaleFonts(frame, scale)
    if not frame then return; end
    
    local regions = {frame:GetRegions()};
    for i = 1, #regions do
        local region = regions[i];
        if region and region:GetObjectType() == "FontString" then
            local fontName, fontSize, fontFlags = region:GetFont();
            if fontName and fontSize then
                -- Для сброса используем scale=1.0, который вернет к размеру из шаблона
                region:SetFont(fontName, fontSize * scale, fontFlags);
            end
        end
    end
    
    local children = {frame:GetChildren()};
    for i = 1, table.getn(children) do
        local child = children[i];
        if child then
            DialogUI_ScaleFonts(child, scale);
        end
    end
end

function DialogUI_ApplyAllSettings()
    DialogUI_ApplyScale();
    DialogUI_ApplyAlpha();
    DialogUI_ApplyFontSize();
    DialogUI_ApplyFont();
end

-- Сохранение/Загрузка конфигурации
function DialogUI_SaveConfig()
    if not DialogUI_SavedConfig then
        DialogUI_SavedConfig = {};
    end

    DialogUI_SavedConfig.scale = DialogUI_Config.scale;
    DialogUI_SavedConfig.alpha = DialogUI_Config.alpha;
    DialogUI_SavedConfig.fontSize = DialogUI_Config.fontSize;
    DialogUI_SavedConfig.fontFile = DialogUI_Config.fontFile;
end

function DialogUI_LoadConfig()
    if DialogUI_SavedConfig then
        DialogUI_Config.scale = DialogUI_SavedConfig.scale or 1.0;
        DialogUI_Config.alpha = DialogUI_SavedConfig.alpha or 1.0;
        DialogUI_Config.fontSize = DialogUI_SavedConfig.fontSize or 1.0;
        DialogUI_Config.fontFile = DialogUI_SavedConfig.fontFile or "frizqt___cyr.ttf";

        DialogUI_ApplyAllSettings();
    end
end

-- Функции показа/скрытия окна конфигурации
function DialogUI_ShowConfig()
    if DConfigFrame then
        ShowUIPanel(DConfigFrame);
    end
end

function DialogUI_HideConfig()
    if DConfigFrame then
        HideUIPanel(DConfigFrame);
    end
end

function DialogUI_ToggleConfig()
    if DConfigFrame and DConfigFrame:IsVisible() then
        DialogUI_HideConfig();
    else
        DialogUI_ShowConfig();
    end
end

-- Специальная функция прозрачности для окна конфигурации
function DialogUI_ApplyConfigAlpha()
    local alpha = DialogUI_Config.alpha;

    if DConfigFrame then
        local layers = {DConfigFrame:GetRegions()};
        for i = 1, table.getn(layers) do
            if layers[i]:GetObjectType() == "Texture" then
                layers[i]:SetAlpha(alpha);
                break;
            end
        end
    end
end

-- ==========================================
-- Функции выбора шрифта
-- ==========================================

function DConfigFrame_UpdateFontButtons()
    local currentFont = DialogUI_Config.fontFile or "frizqt___cyr.ttf";
    
    for i, fontData in ipairs(AVAILABLE_FONTS) do
        local button = getglobal("DConfigFontButton" .. i);
        local check = getglobal("DConfigFontButton" .. i .. "Check");
        
        if button and check then
            if fontData.file == currentFont then
                -- Выбранный шрифт
                check:Show();
                button:SetNormalTexture("Interface\\AddOns\\DialogUI\\src\\assets\\art\\parchment\\ButtonHighlight-Gossip");
            else
                -- Невыбранный шрифт
                check:Hide();
                button:SetNormalTexture("Interface\\AddOns\\DialogUI\\src\\assets\\art\\parchment\\OptionBackground-common");
            end
            
            -- Устанавливаем текст кнопки
            local text = getglobal(button:GetName() .. "Text");
            if text then
                text:SetText(fontData.name);
            end
        end
    end
end

function DConfigFontButton_OnClick(index)
    if not index or index < 1 or index > #AVAILABLE_FONTS then return; end
    
    local fontData = AVAILABLE_FONTS[index];
    if not fontData then return; end
    
    DialogUI_Config.fontFile = fontData.file;
    
    -- Обновляем визуальное состояние кнопок
    DConfigFrame_UpdateFontButtons();
    
    -- Применяем шрифт
    DialogUI_ApplyFont();
    
    -- Сохраняем
    DialogUI_SaveConfig();
    
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("DialogUI: Шрифт изменен на " .. fontData.name);
    end
    
    PlaySound("igMainMenuOptionCheckBoxOn");
end

function DialogUI_ApplyFont()
    local fontFile = DialogUI_Config.fontFile or "frizqt___cyr.ttf";
    local fontPath = "Interface\\AddOns\\DialogUI\\src\\assets\\font\\" .. fontFile;
    
    -- Применяем шрифт ко всем текстовым элементам в DQuestFrame
    if DQuestFrame then
        DialogUI_SetFontForFrame(DQuestFrame, fontPath);
    end
    
    -- Применяем шрифт ко всем текстовым элементам в DGossipFrame
    if DGossipFrame then
        DialogUI_SetFontForFrame(DGossipFrame, fontPath);
    end
    
    -- Применяем шрифт к окну конфигурации
    if DConfigFrame then
        DialogUI_SetFontForFrame(DConfigFrame, fontPath);
    end
end

function DialogUI_SetFontForFrame(frame, fontPath)
    if not frame then return; end
    
    local regions = {frame:GetRegions()};
    for i = 1, #regions do
        local region = regions[i];
        if region and region:GetObjectType() == "FontString" then
            local _, fontSize, fontFlags = region:GetFont();
            if fontSize then
                region:SetFont(fontPath, fontSize, fontFlags);
            end
        end
    end
    
    -- Рекурсивно обрабатываем дочерние фреймы
    local children = {frame:GetChildren()};
    for i = 1, table.getn(children) do
        local child = children[i];
        if child then
            DialogUI_SetFontForFrame(child, fontPath);
        end
    end
end

function DialogUI_GetFontPath()
    local fontFile = DialogUI_Config.fontFile or "frizqt___cyr.ttf";
    return "Interface\\AddOns\\DialogUI\\src\\assets\\font\\" .. fontFile;
end