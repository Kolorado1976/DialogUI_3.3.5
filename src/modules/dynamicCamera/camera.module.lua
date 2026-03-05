-- Модуль динамической камеры для DialogUI
-- Обеспечивает плавные переходы камеры при взаимодействии с NPC
-- Совместимо с WoW 3.3.5
-- ИСПРАВЛЕНО: Теперь камера фокусируется на лицо NPC, а не в ноги

-- Инициализация модуля камеры
DynamicCamera = {};
DynamicCamera.isActive = false;
DynamicCamera.originalDistance = nil;
DynamicCamera.originalPitch = nil;
DynamicCamera.originalYaw = nil;
DynamicCamera.originalView = nil;  -- Сохраняем вид (1-5)
DynamicCamera.transitionActive = false;
DynamicCamera.initialized = false;

-- Настройки камеры по умолчанию
DynamicCamera.config = {
    enabled = true,
    interactionDistance = 3,      -- УМЕНЬШЕНО: Ближе к NPC для face view
    interactionPitch = -0.1,        -- ИЗМЕНЕНО: Почти горизонтально (лицо, а не ноги)
    transitionSpeed = 2.0,        -- Скорость перехода камеры
    enableForGossip = true,
    enableForVendors = true,
    enableForTrainers = true,
    enableForQuests = true,
    usePresetRestore = false,
    presetView = 2,
    savedCameraYaw = nil,
    savedCameraPitch = nil,
    savedCameraDistance = nil,
    -- НОВЫЕ НАСТРОЙКИ для Face View
    useFaceView = true,            -- Включить режим "лицом к NPC"
    faceViewDistance = 2.5,      -- Дистанция для вида на лицо (очень близко)
    useFirstPersonView = true,     -- Использовать вид от первого лица
};

-- Сохранить исходную позицию камеры и вид
function DynamicCamera:SaveOriginalPosition()
    if not self.isActive then
        local distance = 15;
        local pitch = 0;
        local yaw = 0;
        local view = 2;  -- По умолчанию вид от 3-го лица

        if GetCVar then
            local camDist = GetCVar("cameraDistanceMax");
            if camDist then
                distance = tonumber(camDist) or 15;
            end
            -- Сохраняем текущий вид (1-5)
            local currentView = GetCVar("cameraView");
            if currentView then
                view = tonumber(currentView) or 2;
            end
        end

        if self.config.savedCameraPitch then
            pitch = self.config.savedCameraPitch;
        end
        if self.config.savedCameraYaw then
            yaw = self.config.savedCameraYaw;
        end

        self.originalDistance = distance;
        self.originalPitch = pitch;
        self.originalYaw = yaw;
        self.originalView = view;

        -- Сохраняем в SavedVariables
        if not DialogUI_SavedConfig then
            DialogUI_SavedConfig = {};
        end
        DialogUI_SavedConfig.originalCameraDistance = self.originalDistance;
        DialogUI_SavedConfig.originalCameraPitch = self.originalPitch;
        DialogUI_SavedConfig.originalCameraYaw = self.originalYaw;
        DialogUI_SavedConfig.originalView = self.originalView;
    end
end

-- Применить позицию камеры для взаимодействия - ВЕРСИЯ FACE VIEW
function DynamicCamera:ApplyInteractionPosition()
    if not self.config.enabled then
        return;
    end

    if self.isActive then
        return;
    end

    self:SaveOriginalPosition();

    -- НОВЫЙ ПОДХОД: Face View
    if self.config.useFaceView then
        self:ApplyFaceView();
    else
        -- Старый подход - просто приближение
        self:ApplyImmediateCamera(self.config.interactionDistance, self.config.interactionPitch, self.originalYaw);
    end

    self.isActive = true;

    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("DialogUI: Режим Face View активирован");
    end
end

-- НОВАЯ ФУНКЦИЯ: Применить вид "лицом к NPC"
function DynamicCamera:ApplyFaceView()
    if not self.config.useFaceView then
        return;
    end

    -- Способ 1: Вид от первого лица + зум
    if self.config.useFirstPersonView and SetView then
        -- Сохраняем текущий вид перед переключением
        if SaveView then
            SaveView(5);  -- Сохраняем в слот 5 (обычно свободен)
        end

        -- Переключаемся на вид от первого лица
        SetView(1);

        -- Небольшая задержка для применения вида, затем зум
        local zoomFrame = CreateFrame("Frame");
        local elapsed = 0;
        zoomFrame:SetScript("OnUpdate", function(self, delta)
            elapsed = elapsed + delta;
            if elapsed >= 0.05 then  -- Короткая задержка
                -- Применяем дистанцию через CVar для вида от 1-го лица
                if SetCVar then
                    SetCVar("cameraDistanceMax", tostring(DynamicCamera.config.faceViewDistance));
                end
                -- Или используем зум
                if CameraZoomIn then
                    for i = 1, 10 do
                        CameraZoomIn(1.0);
                    end
                end
                zoomFrame:SetScript("OnUpdate", nil);
                zoomFrame = nil;
            end
        end);

    else
        -- Способ 2: Обычный зум с коррекцией угла
        -- Устанавливаем минимальную дистанцию
        if SetCVar then
            SetCVar("cameraDistanceMax", tostring(self.config.faceViewDistance));
        end

        -- Приближаем камеру через зум
        if CameraZoomIn then
            for i = 1, 15 do
                CameraZoomIn(1.0);
            end
        end
    end
end

-- Восстановить исходную позицию камеры
function DynamicCamera:RestoreOriginalPosition()
    if not self.originalDistance then
        return;
    end

    -- Восстанавливаем вид от третьего лица ПЕРВЫМ ДЕЛОМ
    if SetView then
        if self.originalView and self.originalView ~= 1 then
            SetView(self.originalView);
        else
            SetView(2);  -- По умолчанию вид от 3-го лица
        end
    end

    -- Восстанавливаем дистанцию
    if self.config.usePresetRestore and self.config.savedCameraDistance then
        if SetCVar then
            SetCVar("cameraDistanceMax", tostring(self.config.savedCameraDistance));
        end

        if CameraZoomOut and self.config.savedCameraDistance then
            local targetDistance = self.config.savedCameraDistance;
            if targetDistance > 10 then
                for i = 1, 5 do
                    CameraZoomOut(2.0);
                end
            end
        end
    else
        -- Восстанавливаем оригинальную дистанцию
        if SetCVar then
            SetCVar("cameraDistanceMax", tostring(self.originalDistance));
        end

        -- Отдаляем камеру обратно
        if CameraZoomOut and self.originalDistance then
            local currentDist = tonumber(GetCVar("cameraDistanceMax")) or 2;
            if self.originalDistance > currentDist then
                for i = 1, math.ceil(self.originalDistance - currentDist) do
                    CameraZoomOut(1.0);
                end
            end
        end
    end

    -- Очистка
    self.isActive = false;
    self.originalDistance = nil;
    self.originalPitch = nil;
    self.originalYaw = nil;
    self.originalView = nil;

    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("DialogUI: Позиция камеры восстановлена");
    end
end

-- Применить настройки камеры немедленно (запасной метод)
function DynamicCamera:ApplyImmediateCamera(distance, pitch, yaw)
    if CameraZoomIn and CameraZoomOut then
        local currentDist = tonumber(GetCVar("cameraDistanceMax")) or 15;
        local targetDist = distance or 8;

        if currentDist > targetDist then
            for i = 1, math.ceil(currentDist - targetDist) do
                CameraZoomIn(1);
            end
        elseif currentDist < targetDist then
            for i = 1, math.ceil(targetDist - currentDist) do
                CameraZoomOut(1);
            end
        end
    elseif SetCVar then
        if distance then
            SetCVar("cameraDistanceMax", tostring(distance));
            SetCVar("cameraDistanceMaxFactor", "1.0");
        end
    end
end

-- Обработчики событий
function DynamicCamera:OnGossipShow()
    if self.config.enableForGossip then
        self:ApplyInteractionPosition();
    end
end

function DynamicCamera:OnGossipClosed()
    if self.config.enableForGossip and self.isActive then
        self:RestoreOriginalPosition();
    end
end

function DynamicCamera:OnMerchantShow()
    if self.config.enableForVendors then
        self:ApplyInteractionPosition();
    end
end

function DynamicCamera:OnMerchantClosed()
    if self.config.enableForVendors and self.isActive then
        self:RestoreOriginalPosition();
    end
end

function DynamicCamera:OnTrainerShow()
    if self.config.enableForTrainers then
        self:ApplyInteractionPosition();
    end
end

function DynamicCamera:OnTrainerClosed()
    if self.config.enableForTrainers and self.isActive then
        self:RestoreOriginalPosition();
    end
end

function DynamicCamera:OnQuestDetail()
    if self.config.enableForQuests then
        if not self.isActive then
            self:ApplyInteractionPosition();
        end
    end
end

function DynamicCamera:OnQuestFinished()
    if self.config.enableForQuests and self.isActive then
        self:RestoreOriginalPosition();
    end
end

-- Загрузить сохраненную конфигурацию камеры
function DynamicCamera:LoadConfig()
    if DialogUI_SavedConfig and DialogUI_SavedConfig.camera then
        local saved = DialogUI_SavedConfig.camera;
        self.config.enabled = saved.enabled ~= nil and saved.enabled or true;
        self.config.interactionDistance = saved.interactionDistance or 3;
        self.config.interactionPitch = saved.interactionPitch or -0.1;
        self.config.transitionSpeed = saved.transitionSpeed or 2.0;
        self.config.enableForGossip = saved.enableForGossip ~= nil and saved.enableForGossip or true;
        self.config.enableForVendors = saved.enableForVendors ~= nil and saved.enableForVendors or true;
        self.config.enableForTrainers = saved.enableForTrainers ~= nil and saved.enableForTrainers or true;
        self.config.enableForQuests = saved.enableForQuests ~= nil and saved.enableForQuests or true;
        self.config.usePresetRestore = saved.usePresetRestore or false;
        self.config.presetView = saved.presetView or 2;
        self.config.savedCameraYaw = saved.savedCameraYaw;
        self.config.savedCameraPitch = saved.savedCameraPitch;
        self.config.savedCameraDistance = saved.savedCameraDistance;
        -- Загружаем новые настройки Face View
        self.config.useFaceView = saved.useFaceView ~= nil and saved.useFaceView or true;
        self.config.faceViewDistance = saved.faceViewDistance or 2.5;
        self.config.useFirstPersonView = saved.useFirstPersonView ~= nil and saved.useFirstPersonView or true;
    end
end

-- Сохранить конфигурацию камеры
function DynamicCamera:SaveConfig()
    if not DialogUI_SavedConfig then
        DialogUI_SavedConfig = {};
    end
    DialogUI_SavedConfig.camera = {
        enabled = self.config.enabled,
        interactionDistance = self.config.interactionDistance,
        interactionPitch = self.config.interactionPitch,
        transitionSpeed = self.config.transitionSpeed,
        enableForGossip = self.config.enableForGossip,
        enableForVendors = self.config.enableForVendors,
        enableForTrainers = self.config.enableForTrainers,
        enableForQuests = self.config.enableForQuests,
        usePresetRestore = self.config.usePresetRestore,
        presetView = self.config.presetView,
        savedCameraYaw = self.config.savedCameraYaw,
        savedCameraPitch = self.config.savedCameraPitch,
        savedCameraDistance = self.config.savedCameraDistance,
        -- Сохраняем новые настройки
        useFaceView = self.config.useFaceView,
        faceViewDistance = self.config.faceViewDistance,
        useFirstPersonView = self.config.useFirstPersonView,
    };
end

-- Инициализация модуля камеры
function DynamicCamera:Initialize()
    if self.initialized then
        return;
    end

    self:LoadConfig();

    local eventFrame = CreateFrame("Frame", "DynamicCameraEventFrame");
    eventFrame:RegisterEvent("GOSSIP_SHOW");
    eventFrame:RegisterEvent("GOSSIP_CLOSED");
    eventFrame:RegisterEvent("MERCHANT_SHOW");
    eventFrame:RegisterEvent("MERCHANT_CLOSED");
    eventFrame:RegisterEvent("TRAINER_SHOW");
    eventFrame:RegisterEvent("TRAINER_CLOSED");
    eventFrame:RegisterEvent("QUEST_DETAIL");
    eventFrame:RegisterEvent("QUEST_FINISHED");
    eventFrame:RegisterEvent("QUEST_COMPLETE");

    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "GOSSIP_SHOW" then
            DynamicCamera:OnGossipShow();
        elseif event == "GOSSIP_CLOSED" then
            DynamicCamera:OnGossipClosed();
        elseif event == "MERCHANT_SHOW" then
            DynamicCamera:OnMerchantShow();
        elseif event == "MERCHANT_CLOSED" then
            DynamicCamera:OnMerchantClosed();
        elseif event == "TRAINER_SHOW" then
            DynamicCamera:OnTrainerShow();
        elseif event == "TRAINER_CLOSED" then
            DynamicCamera:OnTrainerClosed();
        elseif event == "QUEST_DETAIL" then
            DynamicCamera:OnQuestDetail();
        elseif event == "QUEST_FINISHED" or event == "QUEST_COMPLETE" then
            DynamicCamera:OnQuestFinished();
        end
    end);

    self.initialized = true;

    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("DialogUI: Динамическая камера инициализирована (режим Face View)");
    end
end

-- Слэш-команды
SlashCmdList["DYNAMICCAMERA_TOGGLE"] = function()
    DynamicCamera.config.enabled = not DynamicCamera.config.enabled;
    DynamicCamera:SaveConfig();
    local status = DynamicCamera.config.enabled and "включена" or "отключена";
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("DialogUI: Динамическая камера " .. status);
    end
end;
SLASH_DYNAMICCAMERA_TOGGLE1 = "/togglecamera";
SLASH_DYNAMICCAMERA_TOGGLE2 = "/dcamera";

SlashCmdList["DYNAMICCAMERA_TEST"] = function()
    if DynamicCamera.isActive then
        DynamicCamera:RestoreOriginalPosition();
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("DialogUI: Позиция камеры восстановлена");
        end
    else
        DynamicCamera:ApplyInteractionPosition();
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("DialogUI: Режим Face View применен");
        end
    end
end;
SLASH_DYNAMICCAMERA_TEST1 = "/testcamera";

SlashCmdList["DYNAMICCAMERA_FACEVIEW"] = function()
    DynamicCamera.config.useFaceView = not DynamicCamera.config.useFaceView;
    DynamicCamera:SaveConfig();
    local status = DynamicCamera.config.useFaceView and "включен" or "отключен";
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("DialogUI: Режим Face View " .. status);
    end
end;
SLASH_DYNAMICCAMERA_FACEVIEW1 = "/faceview";

SlashCmdList["DYNAMICCAMERA_QUESTDEBUG"] = function()
    local questVisible = DQuestFrame and DQuestFrame:IsVisible() and "ДА" or "НЕТ";
    local cameraActive = DynamicCamera.isActive and "ДА" or "НЕТ";
    local cameraEnabled = DynamicCamera.config.enabled and "ДА" or "НЕТ";
    local faceView = DynamicCamera.config.useFaceView and "ДА" or "НЕТ";

    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("DialogUI Отладка камеры:");
        DEFAULT_CHAT_FRAME:AddMessage("  Окно квестов видимо = " .. questVisible);
        DEFAULT_CHAT_FRAME:AddMessage("  Камера активна = " .. cameraActive .. ", Включена = " .. cameraEnabled);
        DEFAULT_CHAT_FRAME:AddMessage("  Face View = " .. faceView .. ", Дистанция = " .. DynamicCamera.config.faceViewDistance);
    end
end;
SLASH_DYNAMICCAMERA_QUESTDEBUG1 = "/cameradebug";

SlashCmdList["DYNAMICCAMERA_SAVEPRESET"] = function()
    DynamicCamera:SaveCameraPreset();
end;
SLASH_DYNAMICCAMERA_SAVEPRESET1 = "/savecamerapreset";

function DynamicCamera:ApplyPreset(presetName)
    if presetName == "cinematic" then
        self.config.faceViewDistance = 2.0;
        self.config.useFaceView = true;
    elseif presetName == "close" then
        self.config.faceViewDistance = 1.5;
        self.config.useFaceView = true;
    elseif presetName == "normal" then
        self.config.faceViewDistance = 2.5;
        self.config.useFaceView = true;
    elseif presetName == "wide" then
        self.config.useFaceView = false;
        self.config.interactionDistance = 8;
    end

    self:SaveConfig();
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("DialogUI: Пресет камеры '" .. presetName .. "' применен");
    end
end

SlashCmdList["CAMERA_PRESET"] = function(msg)
    local preset = string.lower(msg or "");
    if preset == "cinematic" or preset == "close" or preset == "normal" or preset == "wide" then
        DynamicCamera:ApplyPreset(preset);
    else
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("DialogUI: Доступные пресеты: cinematic, close, normal, wide");
        end
    end
end;
SLASH_CAMERA_PRESET1 = "/camerapreset";

-- Автоинициализация при загрузке
DynamicCamera:Initialize();