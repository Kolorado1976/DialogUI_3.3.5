-- Dynamic Camera Module for DialogUI
-- Handles smooth camera transitions during NPC interactions
-- Compatible with WoW 3.3.5

-- Initialize the camera module
DynamicCamera = {};
DynamicCamera.isActive = false;
DynamicCamera.originalDistance = nil;
DynamicCamera.originalPitch = nil;
DynamicCamera.originalYaw = nil;
DynamicCamera.transitionActive = false;

-- Default camera settings
DynamicCamera.config = {
    enabled = true,
    interactionDistance = 8,      -- Camera distance when talking to NPC
    interactionPitch = -0.3,      -- Camera pitch (up/down angle)
    transitionSpeed = 2.0,        -- Speed of camera transitions (higher = faster)
    enableForGossip = true,       -- Enable for gossip dialogs
    enableForVendors = true,      -- Enable for vendor interactions
    enableForTrainers = true,     -- Enable for trainer interactions
    enableForQuests = true,       -- Enable for quest dialogs (now ON by default)
    -- Preset system for WotLK 3.3.5
    usePresetRestore = false,     -- Use custom preset instead of trying to restore original
    presetView = 2,              -- Saved camera view (1=first person, 2=third person, etc.)
    savedCameraYaw = nil,        -- Custom saved camera yaw
    savedCameraPitch = nil,      -- Custom saved camera pitch  
    savedCameraDistance = nil,   -- Custom saved camera distance
};

-- Save original camera position
function DynamicCamera:SaveOriginalPosition()
    if not self.isActive then
        -- WoW 3.3.5: Используем GetCVar для получения дистанции камеры
        local distance = 15; -- Default fallback
        local pitch = 0; -- Default fallback
        local yaw = 0; -- Default fallback
        
        -- В 3.3.5 используем CVars для получения настроек камеры
        if GetCVar then
            local camDist = GetCVar("cameraDistanceMax");
            if camDist then
                distance = tonumber(camDist) or 15;
            end
        end
        
        -- В 3.3.5 нет прямого доступа к pitch/yaw, используем значения по умолчанию
        -- или сохраненные ранее значения
        if self.config.savedCameraPitch then
            pitch = self.config.savedCameraPitch;
        end
        if self.config.savedCameraYaw then
            yaw = self.config.savedCameraYaw;
        end
        
        self.originalDistance = distance;
        self.originalPitch = pitch;
        self.originalYaw = yaw;
        
        -- Store in saved variables for persistence
        if not DialogUI_SavedConfig then
            DialogUI_SavedConfig = {};
        end
        DialogUI_SavedConfig.originalCameraDistance = self.originalDistance;
        DialogUI_SavedConfig.originalCameraPitch = self.originalPitch;
        DialogUI_SavedConfig.originalCameraYaw = self.originalYaw;
    end
end

-- Save current camera position as preset for restoration
function DynamicCamera:SaveCameraPreset()
    -- WoW 3.3.5: Используем GetCVar для получения текущей дистанции
    local currentDistance = 15; -- Default fallback
    local currentPitch = 0;
    local currentYaw = 0;
    
    -- Получаем текущую дистанцию камеры через CVar
    if GetCVar then
        local maxDist = GetCVar("cameraDistanceMax");
        if maxDist then
            currentDistance = tonumber(maxDist) or 15;
        end
    end
    
    -- Сохраняем как preset для восстановления
    self.config.usePresetRestore = true;
    self.config.savedCameraDistance = currentDistance;
    self.config.savedCameraPitch = currentPitch;
    self.config.savedCameraYaw = currentYaw;
    self.config.presetView = GetCVar and tonumber(GetCVar("cameraView")) or 2;
    
    -- Save configuration
    self:SaveConfig();
    
    DEFAULT_CHAT_FRAME:AddMessage("DialogUI: Posicion de camara guardada (Distancia: " .. string.format("%.1f", currentDistance) .. ")");
end

-- Restore original camera position
function DynamicCamera:RestoreOriginalPosition()
    if self.originalDistance then
        -- Use saved preset if available
        if self.config.usePresetRestore and self.config.savedCameraDistance then
            -- Restore to saved preset position
            if SetCVar and self.config.savedCameraDistance then
                SetCVar("cameraDistanceMax", tostring(self.config.savedCameraDistance));
            end
            
            -- Restore view mode if available
            if SetView and self.config.presetView then
                SetView(self.config.presetView);
            end
            
            -- Try to restore camera distance using zoom functions as backup
            if CameraZoomOut and self.config.savedCameraDistance then
                local targetDistance = self.config.savedCameraDistance;
                if targetDistance > 10 then
                    -- Zoom out for wider views
                    for i = 1, 3 do
                        CameraZoomOut(2.0);
                    end
                end
            end
        else
            -- Default restore to third-person
            if SetView then
                SetView(2); -- Third person view
            end
            
            -- Reset camera distance to reasonable default
            if SetCVar then
                SetCVar("cameraDistanceMax", "15");
            end
        end
        
        -- Clean up
        self.isActive = false;
        self.originalDistance = nil;
        self.originalPitch = nil;
        self.originalYaw = nil;
    end
end

-- Apply interaction camera position
function DynamicCamera:ApplyInteractionPosition()
    if not self.config.enabled then
        return;
    end
    
    -- Only apply if not already active to avoid interference
    if self.isActive then
        return;
    end
    
    -- Don't interfere if quest frames are in transition or loading
    if DQuestFrame and DQuestFrame:IsVisible() then
        local alpha = DQuestFrame:GetAlpha();
        if alpha < 1.0 then
            -- Frame is still transitioning, wait a bit more
            return;
        end
    end
    
    self:SaveOriginalPosition();
    
    -- Calculate target camera position
    local targetDistance = self.config.interactionDistance;
    local targetPitch = self.config.interactionPitch;
    local currentYaw = self.originalYaw;
    
    -- Apply camera immediately without transition
    self:ApplyImmediateCamera(targetDistance, targetPitch, currentYaw);
    self.isActive = true;
end

-- Apply camera settings immediately without transitions
function DynamicCamera:ApplyImmediateCamera(distance, pitch, yaw)
    -- WoW 3.3.5: Используем CameraZoomIn/CameraZoomOut или SetCVar
    if CameraZoomIn and CameraZoomOut then
        -- Zoom to the target distance immediately
        local currentDist = tonumber(GetCVar("cameraDistanceMax")) or 15;
        local targetDist = distance or 8;
        
        if currentDist > targetDist then
            -- Need to zoom in
            for i = 1, math.ceil(currentDist - targetDist) do
                CameraZoomIn(1);
            end
        elseif currentDist < targetDist then
            -- Need to zoom out
            for i = 1, math.ceil(targetDist - currentDist) do
                CameraZoomOut(1);
            end
        end
    elseif SetCVar then
        -- Use CVars for immediate camera control
        if distance then
            SetCVar("cameraDistanceMax", tostring(distance));
            SetCVar("cameraDistanceMaxFactor", "1.0");
        end
    end
end

-- Smooth camera transition
function DynamicCamera:SmoothTransition(targetDistance, targetPitch, targetYaw, onComplete)
    if self.transitionActive then
        return; -- Avoid multiple transitions
    end
    
    self.transitionActive = true;
    
    -- Use saved values instead of getting current values
    local startDistance = self.originalDistance or 15;
    local startPitch = self.originalPitch or 0;
    local startYaw = self.originalYaw or 0;
    
    -- WoW 3.3.5: Используем CameraZoomIn/CameraZoomOut для плавного перехода
    if CameraZoomIn and targetDistance < startDistance then
        -- Use zoom for closer view
        local steps = math.ceil(startDistance - targetDistance);
        local currentStep = 0;
        
        local zoomFrame = CreateFrame("Frame");
        zoomFrame:SetScript("OnUpdate", function(self, elapsed)
            currentStep = currentStep + 1;
            if currentStep <= steps then
                CameraZoomIn(1.0);
            else
                zoomFrame:SetScript("OnUpdate", nil);
                zoomFrame = nil;
                DynamicCamera.transitionActive = false;
                if onComplete then
                    onComplete();
                end
            end
        end);
    elseif CameraZoomOut and targetDistance > startDistance then
        -- Use zoom out for wider view
        local steps = math.ceil(targetDistance - startDistance);
        local currentStep = 0;
        
        local zoomFrame = CreateFrame("Frame");
        zoomFrame:SetScript("OnUpdate", function(self, elapsed)
            currentStep = currentStep + 1;
            if currentStep <= steps then
                CameraZoomOut(1.0);
            else
                zoomFrame:SetScript("OnUpdate", nil);
                zoomFrame = nil;
                DynamicCamera.transitionActive = false;
                if onComplete then
                    onComplete();
                end
            end
        end);
    elseif SetCVar then
        -- Fallback: используем SetCVar для мгновенного изменения
        SetCVar("cameraDistanceMax", tostring(targetDistance));
        self.transitionActive = false;
        if onComplete then
            onComplete();
        end
    else
        self.transitionActive = false;
        if onComplete then
            onComplete();
        end
    end
end

-- Event handlers
function DynamicCamera:OnGossipShow()
    if self.config.enableForGossip then
        -- Apply camera immediately without delay
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
    -- For quest frames, be very conservative to avoid interference
    if self.config.enableForQuests then
        -- Don't activate camera if already active
        if self.isActive then
            return;
        end
        self:ApplyInteractionPosition();
    end
end

function DynamicCamera:OnQuestFinished()
    if self.config.enableForQuests and self.isActive then
        self:RestoreOriginalPosition();
    end
end

-- Load saved camera configuration
function DynamicCamera:LoadConfig()
    if DialogUI_SavedConfig and DialogUI_SavedConfig.camera then
        local saved = DialogUI_SavedConfig.camera;
        self.config.enabled = saved.enabled ~= nil and saved.enabled or true;
        self.config.interactionDistance = saved.interactionDistance or 8;
        self.config.interactionPitch = saved.interactionPitch or -0.3;
        self.config.transitionSpeed = saved.transitionSpeed or 2.0;
        self.config.enableForGossip = saved.enableForGossip ~= nil and saved.enableForGossip or true;
        self.config.enableForVendors = saved.enableForVendors ~= nil and saved.enableForVendors or true;
        self.config.enableForTrainers = saved.enableForTrainers ~= nil and saved.enableForTrainers or true;
        self.config.enableForQuests = saved.enableForQuests ~= nil and saved.enableForQuests or true;
        -- Load preset settings
        self.config.usePresetRestore = saved.usePresetRestore or false;
        self.config.presetView = saved.presetView or 2;
        self.config.savedCameraYaw = saved.savedCameraYaw;
        self.config.savedCameraPitch = saved.savedCameraPitch;
        self.config.savedCameraDistance = saved.savedCameraDistance;
    end
end

-- Save camera configuration
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
        -- Save preset settings
        usePresetRestore = self.config.usePresetRestore,
        presetView = self.config.presetView,
        savedCameraYaw = self.config.savedCameraYaw,
        savedCameraPitch = self.config.savedCameraPitch,
        savedCameraDistance = self.config.savedCameraDistance,
    };
end

-- Initialize camera module
function DynamicCamera:Initialize()
    -- Load configuration
    self:LoadConfig();
    
    -- Create event frame
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
end

-- Slash commands for camera module
SlashCmdList["DYNAMICCAMERA_TOGGLE"] = function()
    DynamicCamera.config.enabled = not DynamicCamera.config.enabled;
    DynamicCamera:SaveConfig();
    
    local status = DynamicCamera.config.enabled and "enabled" or "disabled";
    DEFAULT_CHAT_FRAME:AddMessage("DialogUI: Dynamic Camera " .. status);
end;
SLASH_DYNAMICCAMERA_TOGGLE1 = "/togglecamera";
SLASH_DYNAMICCAMERA_TOGGLE2 = "/dcamera";

-- Test command for camera positioning
SlashCmdList["DYNAMICCAMERA_TEST"] = function()
    if DynamicCamera.isActive then
        DynamicCamera:RestoreOriginalPosition();
        DEFAULT_CHAT_FRAME:AddMessage("DialogUI: Camera restored");
    else
        DynamicCamera:ApplyInteractionPosition();
        DEFAULT_CHAT_FRAME:AddMessage("DialogUI: Camera applied");
    end
end;
SLASH_DYNAMICCAMERA_TEST1 = "/testcamera";

-- Additional debug command for quest frame compatibility
SlashCmdList["DYNAMICCAMERA_QUESTDEBUG"] = function()
    local questVisible = DQuestFrame and DQuestFrame:IsVisible() and "YES" or "NO";
    local questAlpha = DQuestFrame and DQuestFrame:GetAlpha() or "N/A";
    local cameraActive = DynamicCamera.isActive and "YES" or "NO";
    
    DEFAULT_CHAT_FRAME:AddMessage("DialogUI: QuestFrame Visible=" .. questVisible .. ", Alpha=" .. questAlpha .. ", Camera Active=" .. cameraActive);
end;
SLASH_DYNAMICCAMERA_QUESTDEBUG1 = "/cameradebug";

-- Command to save current camera position as preset
SlashCmdList["DYNAMICCAMERA_SAVEPRESET"] = function()
    DynamicCamera:SaveCameraPreset();
end;
SLASH_DYNAMICCAMERA_SAVEPRESET1 = "/savecamerapreset";
SLASH_DYNAMICCAMERA_SAVEPRESET2 = "/savepreset";

-- Apply camera preset
function DynamicCamera:ApplyPreset(presetName)
    if presetName == "cinematic" then
        self.config.interactionDistance = 6;
        self.config.interactionPitch = -0.5;
    elseif presetName == "close" then
        self.config.interactionDistance = 4;
        self.config.interactionPitch = -0.2;
    elseif presetName == "normal" then
        self.config.interactionDistance = 8;
        self.config.interactionPitch = -0.3;
    elseif presetName == "wide" then
        self.config.interactionDistance = 12;
        self.config.interactionPitch = -0.1;
    end
    
    self:SaveConfig();
    DEFAULT_CHAT_FRAME:AddMessage("DialogUI: Camera preset '" .. presetName .. "' applied");
end

-- Preset commands
SlashCmdList["CAMERA_PRESET"] = function(msg)
    local preset = string.lower(msg or "");
    if preset == "cinematic" or preset == "close" or preset == "normal" or preset == "wide" then
        DynamicCamera:ApplyPreset(preset);
    else
        DEFAULT_CHAT_FRAME:AddMessage("DialogUI: Available presets: cinematic, close, normal, wide");
        DEFAULT_CHAT_FRAME:AddMessage("Usage: /camerapreset [preset_name]");
    end
end;
SLASH_CAMERA_PRESET1 = "/camerapreset";

-- Configuration UI Integration
function DynamicCamera:AddConfigControls()
    local parent = DConfigScrollChild or DConfigFrame;
    if not parent then
        return;
    end
    
    -- Verify DConfigFontLabel exists
    if not DConfigFontLabel then
        return;
    end
    
    -- Create camera section title
    local cameraTitle = parent:CreateFontString("DCameraSectionTitle", "OVERLAY", "DQuestButtonTitleGossip");
    cameraTitle:SetPoint("TOP", DConfigFontLabel, "BOTTOM", 0, -35);
    cameraTitle:SetText("Configuracion de Camara");
    cameraTitle:SetJustifyH("LEFT");
    SetFontColor(cameraTitle, "DarkBrown");
    
    -- Camera enabled checkbox
    local cameraEnabledCheckbox = CreateFrame("CheckButton", "DCameraEnabledCheckbox", parent, "UICheckButtonTemplate");
    cameraEnabledCheckbox:SetPoint("TOPLEFT", cameraTitle, "BOTTOMLEFT", 0, -10);
    cameraEnabledCheckbox:SetScale(0.8);
    cameraEnabledCheckbox:SetChecked(self.config.enabled);
    
    local cameraEnabledLabel = parent:CreateFontString("DCameraEnabledLabel", "OVERLAY", "DQuestButtonTitleGossip");
    cameraEnabledLabel:SetPoint("LEFT", cameraEnabledCheckbox, "RIGHT", 5, 0);
    cameraEnabledLabel:SetText("Activar Camara Dinamica");
    SetFontColor(cameraEnabledLabel, "DarkBrown");
    
    cameraEnabledCheckbox:SetScript("OnClick", function()
        DynamicCamera.config.enabled = cameraEnabledCheckbox:GetChecked();
        DynamicCamera:SaveConfig();
        
        local status = DynamicCamera.config.enabled and "activada" or "desactivada";
        DEFAULT_CHAT_FRAME:AddMessage("DialogUI: Camara Dinamica " .. status);
    end);
    
    -- Settings display
    local settingsRow = parent:CreateFontString("DCameraSettingsLabel", "OVERLAY", "DQuestButtonTitleGossip");
    settingsRow:SetPoint("TOPLEFT", cameraEnabledCheckbox, "BOTTOMLEFT", 0, -20);
    settingsRow:SetText("Distancia: " .. string.format("%.1f", self.config.interactionDistance) .. 
                       " | Angulo: " .. string.format("%.1f", self.config.interactionPitch) .. 
                       " | Velocidad: " .. string.format("%.1f", self.config.transitionSpeed));
    SetFontColor(settingsRow, "DarkBrown");
    
    -- Store reference for updates
    self.settingsLabel = settingsRow;
    
    -- Interaction types
    local typesLabel = parent:CreateFontString("DInteractionTypesLabel", "OVERLAY", "DQuestButtonTitleGossip");
    typesLabel:SetPoint("TOPLEFT", settingsRow, "BOTTOMLEFT", 0, -15);
    typesLabel:SetText("Activar para: ");
    SetFontColor(typesLabel, "DarkBrown");
    
    -- Horizontal layout for checkboxes
    local checkboxData = {
        {name = "Comercio", config = "enableForGossip", xOffset = 0},
        {name = "Vendedores", config = "enableForVendors", xOffset = 80},
        {name = "Entrenadores", config = "enableForTrainers", xOffset = 160},
        {name = "Misiones", config = "enableForQuests", xOffset = 240}
    };
    
    for i, data in ipairs(checkboxData) do
        local checkbox = CreateFrame("CheckButton", "DCamera" .. data.name .. "Checkbox", parent, "UICheckButtonTemplate");
        checkbox:SetPoint("TOPLEFT", typesLabel, "BOTTOMLEFT", data.xOffset, -10);
        checkbox:SetScale(0.7);
        checkbox:SetChecked(self.config[data.config]);
        
        local label = parent:CreateFontString("DCamera" .. data.name .. "Label", "OVERLAY", "DQuestButtonTitleGossip");
        label:SetPoint("LEFT", checkbox, "RIGHT", 2, 0);
        label:SetText(data.name);
        SetFontColor(label, "DarkBrown");
        
        checkbox:SetScript("OnClick", function()
            DynamicCamera.config[data.config] = checkbox:GetChecked();
            DynamicCamera:SaveConfig();
        end);
    end
    
    -- Quick preset section
    local presetsLabel = parent:CreateFontString("DCameraPresetsLabel", "OVERLAY", "DQuestButtonTitleGossip");
    presetsLabel:SetPoint("TOPLEFT", typesLabel, "BOTTOMLEFT", 0, -45);
    presetsLabel:SetText("Vistas Rapidas:");
    SetFontColor(presetsLabel, "DarkBrown");
    
    -- Save Current Camera Preset button
    local savePresetBtn = CreateFrame("Button", "DSavePresetButton", parent, "DUIPanelButtonTemplate");
    savePresetBtn:SetPoint("TOPLEFT", presetsLabel, "BOTTOMLEFT", 0, -10);
    savePresetBtn:SetWidth(150);
    savePresetBtn:SetHeight(25);
    savePresetBtn:SetText("Guardar Vista Actual");
    savePresetBtn:SetScript("OnClick", function()
        DynamicCamera:SaveCameraPreset();
    end);
    
    -- Preset info
    local presetInfo = parent:CreateFontString("DCameraPresetInfo", "OVERLAY", "DQuestButtonTitleGossip");
    presetInfo:SetPoint("TOPLEFT", savePresetBtn, "BOTTOMLEFT", 0, -5);
    presetInfo:SetWidth(300);
    presetInfo:SetJustifyH("LEFT");
    presetInfo:SetText("Ajusta tu camara como quieres que quede despues de hablar con NPCs, luego guarda la vista.");
    SetFontColor(presetInfo, "LightBrown");
    
    -- Preset buttons
    local presets = {"Cinematic", "Close", "Normal", "Wide"};
    local presetNames = {"Cinematica", "Cerca", "Normal", "Amplia"};
    for i, presetName in ipairs(presets) do
        local button = CreateFrame("Button", "DCamera" .. presetName .. "Button", parent, "DUIPanelButtonTemplate");
        button:SetText(presetNames[i]);
        button:SetWidth(80);
        button:SetHeight(22);
        
        -- Position buttons in a row
        button:SetPoint("TOPLEFT", presetInfo, "BOTTOMLEFT", (i-1) * 85, -10);
        button:SetScript("OnClick", function()
            DynamicCamera:ApplyPreset(string.lower(presetName));
            -- Update display
            if DynamicCamera.settingsLabel then
                DynamicCamera.settingsLabel:SetText("Distancia: " .. string.format("%.1f", DynamicCamera.config.interactionDistance) .. 
                                                   " | Angulo: " .. string.format("%.1f", DynamicCamera.config.interactionPitch) .. 
                                                   " | Velocidad: " .. string.format("%.1f", DynamicCamera.config.transitionSpeed));
            end
        end);
    end
end