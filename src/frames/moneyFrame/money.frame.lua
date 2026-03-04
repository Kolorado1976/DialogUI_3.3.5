MONEY_ICON_WIDTH = 19;
MONEY_ICON_WIDTH_SMALL = 13;

MONEY_BUTTON_SPACING = -4;
MONEY_BUTTON_SPACING_SMALL = -4;

COPPER_PER_SILVER = 100;
SILVER_PER_GOLD = 100;
COPPER_PER_GOLD = COPPER_PER_SILVER * SILVER_PER_GOLD;

COIN_BUTTON_WIDTH = 32;

MoneyTypeInfo = { };
MoneyTypeInfo["PLAYER"] = {
    UpdateFunc = function()
        return (GetMoney() - GetCursorMoney() - GetPlayerTradeMoney());
    end,

    PickupFunc = function(amount)
        PickupPlayerMoney(amount);
    end,

    DropFunc = function()
        DropCursorMoney();
    end,

    collapse = 1,
    canPickup = 1,
    showSmallerCoins = "Backpack"
};
MoneyTypeInfo["STATIC"] = {
    UpdateFunc = function()
        return this.staticMoney;
    end,

    collapse = 1,
};
MoneyTypeInfo["AUCTION"] = {
    UpdateFunc = function()
        return this.staticMoney;
    end,
    showSmallerCoins = "Backpack",
    fixedWidth = 1,
    collapse = 1,
    truncateSmallCoins = nil,
};
MoneyTypeInfo["PLAYER_TRADE"] = {
    UpdateFunc = function()
        return GetPlayerTradeMoney();
    end,

    PickupFunc = function(amount)
        PickupTradeMoney(amount);
    end,

    DropFunc = function()
        AddTradeMoney();
    end,

    collapse = 1,
    canPickup = 1,
};
MoneyTypeInfo["TARGET_TRADE"] = {
    UpdateFunc = function()
        return GetTargetTradeMoney();
    end,

    collapse = 1,
};
MoneyTypeInfo["SEND_MAIL"] = {
    UpdateFunc = function()
        return GetSendMailMoney();
    end,

    PickupFunc = function(amount)
        PickupSendMailMoney(amount);
    end,

    DropFunc = function()
        AddSendMailMoney();
    end,

    collapse = nil,
    canPickup = 1,
    showSmallerCoins = "Backpack",
};
MoneyTypeInfo["SEND_MAIL_COD"] = {
    UpdateFunc = function()
        return GetSendMailCOD();
    end,

    PickupFunc = function(amount)
        PickupSendMailCOD(amount);
    end,

    DropFunc = function()
        AddSendMailCOD();
    end,

    collapse = 1,
    canPickup = 1,
};

function MoneyFrame_OnLoad()
    -- ГАРАНТИРОВАННО устанавливаем moneyType и info ПЕРЕД всем остальным
    this.moneyType = "PLAYER";
    this.info = MoneyTypeInfo["PLAYER"];
    this.staticMoney = 0;

    this:RegisterEvent("PLAYER_MONEY");
    this:RegisterEvent("PLAYER_TRADE_MONEY");
    this:RegisterEvent("TRADE_MONEY_CHANGED");
    this:RegisterEvent("SEND_MAIL_MONEY_CHANGED");
    this:RegisterEvent("SEND_MAIL_COD_CHANGED");
end

function SmallMoneyFrame_OnLoad()
    -- ГАРАНТИРОВАННО устанавливаем moneyType и info ПЕРЕД всем остальным
    this.moneyType = "PLAYER";
    this.info = MoneyTypeInfo["PLAYER"];
    this.staticMoney = 0;
    this.small = 1;

    this:RegisterEvent("PLAYER_MONEY");
    this:RegisterEvent("PLAYER_TRADE_MONEY");
    this:RegisterEvent("TRADE_MONEY_CHANGED");
    this:RegisterEvent("SEND_MAIL_MONEY_CHANGED");
    this:RegisterEvent("SEND_MAIL_COD_CHANGED");
end

-- Безопасная версия установки типа
-- ИСПРАВЛЕНО: переименован параметр 'type' в 'moneyType' чтобы избежать конфликта с функцией type()
function MoneyFrame_SetTypeSafe(moneyType)
    if not moneyType then
        moneyType = "PLAYER";
    end

    -- ИСПРАВЛЕНО: используем typeof вместо type для проверки типа
    local typeOfArg = type(moneyType)

    -- Если передан тип как строка
    if typeOfArg == "string" then
        local info = MoneyTypeInfo[moneyType];
        if info then
            this.info = info;
            this.moneyType = moneyType;
        else
            -- Если тип не найден, используем PLAYER
            this.info = MoneyTypeInfo["PLAYER"];
            this.moneyType = "PLAYER";
        end
    -- Если передана таблица (от другого аддона)
    elseif typeOfArg == "table" then
        -- Пытаемся использовать переданную таблицу как info
        this.info = moneyType;
        -- Пытаемся определить тип из таблицы
        if moneyType.moneyType and type(moneyType.moneyType) == "string" then
            this.moneyType = moneyType.moneyType;
        else
            this.moneyType = "PLAYER";
        end

        -- Добавляем недостающие поля если их нет
        if not this.info.UpdateFunc then
            this.info.UpdateFunc = function() 
                return GetMoney(); 
            end;
        end
        if this.info.collapse == nil then
            this.info.collapse = 1;
        end
    else
        -- По умолчанию используем PLAYER
        this.info = MoneyTypeInfo["PLAYER"];
        this.moneyType = "PLAYER";
    end

    local frameName = this:GetName();
    if not frameName then return; end

    local info = this.info;

    -- Безопасная установка кликабельности кнопок
    local goldButton = getglobal(frameName .. "GoldButton");
    local silverButton = getglobal(frameName .. "SilverButton");
    local copperButton = getglobal(frameName .. "CopperButton");

    if info and info.canPickup then
        if goldButton then goldButton:EnableMouse(true); end
        if silverButton then silverButton:EnableMouse(true); end
        if copperButton then copperButton:EnableMouse(true); end
    else
        if goldButton then goldButton:EnableMouse(false); end
        if silverButton then silverButton:EnableMouse(false); end
        if copperButton then copperButton:EnableMouse(false); end
    end

    DMoneyFrame_UpdateMoney();
end

function MoneyFrame_OnEvent()
    -- Проверяем наличие info и видимость фрейма
    if not this or not this.info or not this:IsVisible() then
        return;
    end

    if (event == "PLAYER_MONEY" and this.moneyType == "PLAYER") then
        DMoneyFrame_UpdateMoney();
    elseif (event == "PLAYER_TRADE_MONEY" and (this.moneyType == "PLAYER" or this.moneyType == "PLAYER_TRADE")) then
        DMoneyFrame_UpdateMoney();
    elseif (event == "TRADE_MONEY_CHANGED" and this.moneyType == "TARGET_TRADE") then
        DMoneyFrame_UpdateMoney();
    elseif (event == "SEND_MAIL_MONEY_CHANGED" and (this.moneyType == "PLAYER" or this.moneyType == "SEND_MAIL")) then
        DMoneyFrame_UpdateMoney();
    elseif (event == "SEND_MAIL_COD_CHANGED" and (this.moneyType == "PLAYER" or this.moneyType == "SEND_MAIL_COD")) then
        DMoneyFrame_UpdateMoney();
    end
end

-- ИСПРАВЛЕНО: переименован параметр 'type' в 'moneyType'
function MoneyFrame_SetType(moneyType)
    MoneyFrame_SetTypeSafe(moneyType);
end

-- Update the money shown in a money frame
function DMoneyFrame_UpdateMoney()
    -- Проверяем наличие this
    if not this then return; end

    -- ГАРАНТИРОВАННО создаем info и moneyType если их нет
    if not this.info then
        this.info = MoneyTypeInfo["PLAYER"];
    end
    if not this.moneyType then
        this.moneyType = "PLAYER";
    end

    local money = 0;
    if this.info and this.info.UpdateFunc then
        -- Безопасный вызов функции обновления
        local success, result = pcall(this.info.UpdateFunc);
        if success then
            money = result or 0;
        else
            money = this.staticMoney or GetMoney(); -- fallback
        end
    else
        money = this.staticMoney or GetMoney();
    end

    DMoneyFrame_Update(this:GetName(), money);

    if this.hasPickup == 1 then
        UpdateCoinPickupFrame(money);
    end
end

function DMoneyFrame_Update(frameName, money)
    if not frameName then return; end

    local frame = getglobal(frameName);
    if not frame then return; end

    -- ГАРАНТИРОВАННО создаем info если нужно
    if not frame.info then
        frame.info = MoneyTypeInfo["PLAYER"];
        frame.moneyType = "PLAYER";
    end
    if not frame.moneyType then
        frame.moneyType = "PLAYER";
    end

    local info = frame.info;

    -- Breakdown the money into denominations
    local gold = floor(money / (COPPER_PER_SILVER * SILVER_PER_GOLD));
    local silver = floor((money - (gold * COPPER_PER_SILVER * SILVER_PER_GOLD)) / COPPER_PER_SILVER);
    local copper = mod(money, COPPER_PER_SILVER);

    local goldButton = getglobal(frameName.."GoldButton");
    local silverButton = getglobal(frameName.."SilverButton");
    local copperButton = getglobal(frameName.."CopperButton");

    -- Проверяем существование кнопок
    if not goldButton or not silverButton or not copperButton then
        return;
    end

    local iconWidth = MONEY_ICON_WIDTH;
    local spacing = MONEY_BUTTON_SPACING;
    if ( frame.small ) then
        iconWidth = MONEY_ICON_WIDTH_SMALL;
        spacing = MONEY_BUTTON_SPACING_SMALL;
    end

    -- Set values for each denomination
        -- Set values for each denomination - используем FontString вместо кнопки
    local goldText = getglobal(frameName.."GoldButtonText");
    local silverText = getglobal(frameName.."SilverButtonText");
    local copperText = getglobal(frameName.."CopperButtonText");
    
    if goldText then
        goldText:SetText(gold);
        goldButton:SetWidth(goldText:GetWidth() + iconWidth);
    else
        goldButton:SetText(gold);
        goldButton:SetWidth(goldButton:GetTextWidth() + iconWidth);
    end
    goldButton:Show();
    
    if silverText then
        silverText:SetText(silver);
        silverButton:SetWidth(silverText:GetWidth() + iconWidth);
    else
        silverButton:SetText(silver);
        silverButton:SetWidth(silverButton:GetTextWidth() + iconWidth);
    end
    silverButton:Show();
    
    if copperText then
        copperText:SetText(copper);
        copperButton:SetWidth(copperText:GetWidth() + iconWidth);
    else
        copperButton:SetText(copper);
        copperButton:SetWidth(copperButton:GetTextWidth() + iconWidth);
    end
    copperButton:Show();

    -- Store how much money the frame is displaying
    frame.staticMoney = money;

    -- If not collapsable don't need to continue
    if ( not info.collapse ) then
        return;
    end

    local width = iconWidth;
    local showLowerDenominations, truncateCopper;
    if ( gold > 0 ) then
        width = width + goldButton:GetWidth();
        if ( info.showSmallerCoins ) then
            showLowerDenominations = 1;
        end
        if ( info.truncateSmallCoins ) then
            truncateCopper = 1;
        end
    else
        goldButton:Hide();
    end

    if ( silver > 0 or showLowerDenominations ) then
        -- Exception if showLowerDenominations and fixedWidth
        if ( showLowerDenominations and info.fixedWidth ) then
            silverButton:SetWidth(COIN_BUTTON_WIDTH);
        end

        width = width + silverButton:GetWidth();
        goldButton:SetPoint("RIGHT", frameName.."SilverButton", "LEFT", spacing, 0);
        if ( goldButton:IsVisible() ) then
            width = width - spacing;
        end
        if ( info.showSmallerCoins ) then
            showLowerDenominations = 1;
        end
    else
        silverButton:Hide();
        goldButton:SetPoint("RIGHT", frameName.."SilverButton", "RIGHT", 0, 0);
    end
	

    -- Used if we're not showing lower denominations
    if ( (copper > 0 or showLowerDenominations or info.showSmallerCoins == "Backpack") and not truncateCopper) then
        -- Exception if showLowerDenominations and fixedWidth
        if ( showLowerDenominations and info.fixedWidth ) then
            copperButton:SetWidth(COIN_BUTTON_WIDTH);
        end

        width = width + copperButton:GetWidth();
        silverButton:SetPoint("RIGHT", frameName.."CopperButton", "LEFT", spacing, 0);
        if ( silverButton:IsVisible() ) then
            width = width - spacing;
        end
    else
        copperButton:Hide();
        silverButton:SetPoint("RIGHT", frameName.."CopperButton", "RIGHT", 0, 0);
    end

    frame:SetWidth(width);
end

function SetMoneyFrameColor(frameName, r, g, b)
    if not frameName then return; end

    local goldButton = getglobal(frameName.."GoldButton");
    local silverButton = getglobal(frameName.."SilverButton");
    local copperButton = getglobal(frameName.."CopperButton");

    if goldButton and goldButton.SetTextColor then
        goldButton:SetTextColor(r, g, b);
    end

    if silverButton and silverButton.SetTextColor then
        silverButton:SetTextColor(r, g, b);
    end

    if copperButton and copperButton.SetTextColor then
        copperButton:SetTextColor(r, g, b);
    end
end