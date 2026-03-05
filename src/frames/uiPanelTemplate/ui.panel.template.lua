function ScrollFrameTemplate_OnMouseWheel(value, scrollBar)
    -- Безопасное получение значения колесика
    local delta = 0;
    
    if type(value) == "number" then
        delta = value;
    elseif type(value) == "table" then
        -- Если это таблица, пытаемся получить первый элемент
        delta = tonumber(value[1]) or 0;
    else
        -- Пытаемся преобразовать в число
        delta = tonumber(value) or 0;
    end
    
    -- Проверяем существование this
    local frame = this;
    if not frame then return; end
    
    -- Получаем скроллбар
    scrollBar = scrollBar or getglobal(frame:GetName() .. "ScrollBar");
    if not scrollBar then return; end
    
    -- Прокручиваем
    if (delta > 0) then
        scrollBar:SetValue(scrollBar:GetValue() - (scrollBar:GetHeight() / 2));
    elseif (delta < 0) then
        scrollBar:SetValue(scrollBar:GetValue() + (scrollBar:GetHeight() / 2));
    end
end

-- Scrollframe functions
function ScrollFrame_OnLoad()
    -- Проверяем существование this
    local frame = this;
    if not frame then return; end
    
    local frameName = frame:GetName();
    if not frameName then return; end
    
    local scrollBarName = frameName .. "ScrollBar";
    local downButton = getglobal(scrollBarName .. "ScrollDownButton");
    local upButton = getglobal(scrollBarName .. "ScrollUpButton");
    
    if downButton then downButton:Disable(); end
    if upButton then upButton:Disable(); end

    local scrollbar = getglobal(scrollBarName);
    if scrollbar then
        scrollbar:SetMinMaxValues(0, 0);
        scrollbar:SetValue(0);
    end
    frame.offset = 0;
end

function ScrollFrame_OnScrollRangeChanged(scrollrange)
    -- Проверяем существование this
    local frame = this;
    if not frame then return; end
    
    local frameName = frame:GetName();
    if not frameName then return; end
    
    -- Проверка: если scrollrange это таблица, извлекаем значение
    if type(scrollrange) == "table" then
        scrollrange = scrollrange[1] or 0;
    end
    
    -- Убедимся что scrollrange это число
    scrollrange = tonumber(scrollrange) or 0;
    
    local scrollbarName = frameName .. "ScrollBar";
    local scrollbar = getglobal(scrollbarName);
    if not scrollbar then return; end
    
    if (not scrollrange or scrollrange == 0) then
        local range = frame:GetVerticalScrollRange();
        if type(range) == "table" then
            range = range[1] or 0;
        end
        scrollrange = tonumber(range) or 0;
    end
    
    -- Еще раз проверяем что scrollrange число
    if type(scrollrange) == "table" then
        scrollrange = scrollrange[1] or 0;
    end
    scrollrange = tonumber(scrollrange) or 0;
    
    local value = scrollbar:GetValue();
    if (value > scrollrange) then
        value = scrollrange;
    end
    scrollbar:SetMinMaxValues(0, scrollrange);
    scrollbar:SetValue(value);
    
    -- Получаем кнопки
    local downButton = getglobal(scrollbarName .. "ScrollDownButton");
    local upButton = getglobal(scrollbarName .. "ScrollUpButton");
    local thumbTexture = getglobal(scrollbarName .. "ThumbTexture");
    
    -- Безопасное сравнение с использованием floor
    local scrollrangeNum = floor(scrollrange);
    if (scrollrangeNum == 0) then
        if (frame.scrollBarHideable) then
            -- Скрываем скроллбар и кнопки
            if scrollbar then scrollbar:Hide(); end
            if downButton then downButton:Hide(); end
            if upButton then upButton:Hide(); end
        else
            -- Отключаем кнопки
            if downButton then downButton:Disable(); downButton:Show(); end
            if upButton then upButton:Disable(); upButton:Show(); end
        end
        if thumbTexture then thumbTexture:Hide(); end
    else
        -- Показываем и включаем все
        if downButton then downButton:Show(); downButton:Enable(); end
        if upButton then upButton:Show(); upButton:Enable(); end
        if scrollbar then scrollbar:Show(); end
        if thumbTexture then thumbTexture:Show(); end
    end

    -- Hide/show scrollframe borders
    local top = getglobal(frameName .. "Top");
    local bottom = getglobal(frameName .. "Bottom");
    local middle = getglobal(frameName .. "Middle");
    
    if (top and bottom and frame.scrollBarHideable) then
        -- Безопасное получение диапазона прокрутки
        local verticalRange = frame:GetVerticalScrollRange();
        if type(verticalRange) == "table" then
            verticalRange = verticalRange[1] or 0;
        end
        verticalRange = tonumber(verticalRange) or 0;
        
        if (verticalRange == 0) then
            top:Hide();
            bottom:Hide();
        else
            top:Show();
            bottom:Show();
        end
    end
    
    if (middle and frame.scrollBarHideable) then
        -- Безопасное получение диапазона прокрутки
        local verticalRange = frame:GetVerticalScrollRange();
        if type(verticalRange) == "table" then
            verticalRange = verticalRange[1] or 0;
        end
        verticalRange = tonumber(verticalRange) or 0;
        
        if (verticalRange == 0) then
            middle:Hide();
        else
            middle:Show();
        end
    end
end

function ScrollingEdit_OnTextChanged(scrollFrame)
    local frame = this;
    if not frame then return; end
    
    if (not scrollFrame) then
        scrollFrame = frame:GetParent();
    end
end

function ScrollingEdit_OnCursorChanged(x, y, w, h)
    local frame = this;
    if not frame then return; end
    
    frame.cursorOffset = y;
    frame.cursorHeight = h;
end