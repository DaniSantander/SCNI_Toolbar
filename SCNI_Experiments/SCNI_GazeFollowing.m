function Params = SCNI_GazeFollowing(Params)

%========================== SCNI_GazeFollowing.m ==========================
% This function runs a gaze following experiment based on pre-rendered
% images and animations containing. 
% Experimental parameters can be adjusted by running the accompanying 
% SCNI_GazeFollowingSettings.m GUI and saving to your parameters file.
%
%
%==========================================================================

%================= SET DEFAULT PARAMETERS
if nargin == 0 || ~isfield(Params,'GF')
    Params = SCNI_GazeFollowingSettings(Params, 0);
end

%================= LOAD STIMULUS SET PARAMS
StimParamsFile 	= wildcardsearch(Params.GF.StimDir, '*.mat');
Stim            = load(StimParamsFile{1});
Params.GF.Stim  = Stim.Stim;
Params.GF.TargetGazeRadius = 1.5;

Params.GF.TrialStageDur     = [Params.GF.InitialFix, Params.GF.TargetDur, Params.GF.CueDur, Params.GF.RespFixDur, 500, 1000]/10^3;
Params.GF.StagesPerTrial    = 6;
Params.GF.PDlevels          = logspace(0,2,Params.GF.StagesPerTrial)*2.5; %logspace(0, 255, Params.GF.StagesPerTrial);

Params.Eye.CalMode  = 1;

%================= PRE-ALLOCATE RUN AND REWARD FIELDS
Params.Run.MaxDuration          = sum(Params.GF.TrialStageDur);
Params.Run.ValidFixations       = nan(Params.GF.TrialsPerRun, Params.Run.MaxDuration*Params.DPx.AnalogInRate, 3);
Params.Run.Correct              = nan(Params.GF.TrialsPerRun);
Params.Run.LastRewardTime       = GetSecs;
Params.Run.StartTime            = GetSecs;
Params.Run.LastPress            = GetSecs;
Params.Run.TextColor            = [1,1,1]*255;
Params.Run.TextRect             = [100, 100, [100, 100]+[200,300]];
Params.Run.MaxTrialDur          = 5;                            % Maximum trial duration (seconds)
Params.Run.TrialCount           = 1;                            % Start trial count at 1
Params.Run.ExpQuit              = 0;
if ~isfield(Params.Run, 'Number')                               % If run count field does not exist...
    Params.Run.Number          	= 1;                            % This is the first run of the session
else
    Params.Run.Number          	= Params.Run.Number + 1;        % Advance run count
end
    
if ~isfield(Params, 'Reward')
    Params.Reward.Proportion        = 0.7;                          % Set proportion of reward interval that fixation must be maintained for (0-1)
    Params.Reward.LastRewardTime    = GetSecs;                      % Initialize last reward delivery time (seconds)
    %Params.Reward.NextRewardInt     = Params.Reward.MeanIRI + rand(1)*Params.Reward.RandIRI;           	% Generate random interval before first reward delivery (seconds)
    Params.Reward.TTLDur            = 0.05;                         % Set TTL pulse duration (seconds)
    Params.Reward.RunCount          = 0;                            % Count how many reward delvieries in this run
end
Params.DPx.UseDPx               = 1;                            % Use DataPixx?

if ~isfield(Params, 'Eye')
    Params = SCNI_EyeCalibSettings(Params);
end

%================= OPEN NEW PTB WINDOW?
% if ~isfield(Params.Display, 'win')
    HideCursor;   
    
    Screen('Preference', 'VisualDebugLevel', 0);   
    Params.Display.ScreenID = max(Screen('Screens'));
    [Params.Display.win]    = Screen('OpenWindow', Params.Display.ScreenID, Params.Display.Exp.BackgroundColor, Params.Display.XScreenRect,[],[], [], []);
    Screen('BlendFunction', Params.Display.win, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);                        % Enable alpha channel
    Params.Display.ExpRect  = Params.Display.Rect;
    Params                  = SCNI_InitializeGrid(Params);
% end

%================= INITIALIZE DATAPIXX
if Params.DPx.UseDPx == 1
    Params = SCNI_DataPixxInit(Params);
end

%================= INITIALIZE KEYBOARD SHORTCUTS
KbName('UnifyKeyNames');
KeyNames                    = {'Escape','R','A','C'};         
KeyFunctions                = {'Stop','Reward','Audio','CenterEyes'};
Params.GF.KeysList   	= zeros(1,256); 
for k = 1:numel(KeyNames)
    eval(sprintf('Params.GF.Keys.%s = KbName(''%s'');', KeyFunctions{k}, KeyNames{k}));
    eval(sprintf('Params.GF.KeysList(Params.GF.Keys.%s) = 1;', KeyFunctions{k}));
end

%================= INITIALIZE AUDIO
Params = SCNI_AudioSettings(Params);

%================= GENERATE FIXATION TEXTURE
if Params.GF.FixType > 1
    Fix.Type        = Params.GF.FixType;                        % Fixation marker format
    Fix.Color       = Params.GF.FixColor;                       % Fixation marker color (RGB, 0-1)
    Fix.MarkerSize  = Params.GF.FixDiameter;                  	% Fixation marker diameter (degrees)
    Fix.LineWidth   = 4;                                        % Fixation marker line width (pixels)
    Fix.Size        = Fix.MarkerSize*Params.Display.PixPerDeg;
    Params.GF.FixTex = SCNI_GenerateFixMarker(Fix, Params);     
end

%================ PREPARE GRID FOR EXP. DISPLAY
Params  = SCNI_InitializeGrid(Params);
Params	= SCNI_GetPDrect(Params, Params.GF.Use3D);

%================= CALCULATE SCREEN RECTANGLES
Params.GF.RectExp   	= Params.Display.Rect;
Params.GF.RectMonk    	= Params.Display.Rect + [Params.Display.Rect(3), 0, Params.Display.Rect(3), 0];
Params.GF.GazeFixRect  	= CenterRect([1,1,Params.GF.FixWinDeg.*Params.Display.PixPerDeg], Params.Display.Rect);

%================= ADJUST FOR 3D FORMAT...
Params.GF.ImageRes = Params.Display.Rect([3,4]);
if Params.GF.Use3D == 1
    NoEyes                              = 2;
  	Params.GF.SourceRectExp             = [1, 1, Params.GF.ImageRes(1)/2, Params.GF.ImageRes(2)];
    Params.GF.SourceRectMonk            = [1, 1, Params.GF.ImageRes];
    Params.Display.FixRectExp           = CenterRect([1, 1, Fix.Size], Params.Display.Rect);
    Params.Display.FixRectMonk(1,:)     = CenterRect([1, 1, Fix.Size./[2,1]], Params.Display.Rect./[1,1,2,1]) + [Params.Display.Rect(3),0,Params.Display.Rect(3),0]; 
    Params.Display.FixRectMonk(2,:)     = Params.Display.FixRectMonk(1,:) + Params.Display.Rect([3,1,3,1]).*[0.5,0,0.5,0];
    
elseif Params.GF.Use3D == 0
    NoEyes                              = 1;
	Params.GF.SourceRectExp             = [];
    Params.GF.SourceRectMonk            = [];
    Params.Display.FixRectExp           = CenterRect([1, 1, Fix.Size], Params.Display.Rect);
    Params.Display.FixRectMonk(1,:)     = CenterRect([1, 1, Fix.Size], Params.Display.Rect + [Params.Display.Rect(3), 0, Params.Display.Rect(3), 0]); 
    Params.Display.FixRectMonk(2,:)     = Params.Display.FixRectMonk(1,:);
end
Params.Eye.GazeRect     = Params.GF.GazeFixRect;
Params.GF.TargetRect    = [1, 1, 2*Params.GF.TargetGazeRadius.*Params.Display.PixPerDeg];

%================= LOAD FRAMES TO GPU
if ~isfield(Params.GF, 'TargetTex')
	Params = SCNI_LoadGFframes(Params);
end

%================= LOAD / GENERATE STIMULUS ORDER
Params = GenerateGFDesign(Params);





%% ============================ BEGIN RUN =================================
while Params.Run.TrialCount < Params.GF.TrialsPerRun && Params.Run.ExpQuit == 0
    AdcStatus = SCNI_StartADC(Params);                                          % Start DataPixx ADC
    
    %================== BEGIN NEXT TRIAL
    for TrialStage = 1:Params.GF.StagesPerTrial                              	% Loop through trial stages
        
        Params.Run.CurrentTrialStage    = TrialStage;
        Params.GF.StageTransTime        = GetSecs;
        NewStage                        = 1; 
        PhotodiodeColor                 = repmat(Params.GF.PDlevels(TrialStage),[1,3]);
        
        %================== BEGIN NEXT STAGE OF TRIAL
        switch TrialStage 
            case 1      %================== Initial fixation
                if Params.GF.UseAudioCue == 1
                    Params          = SCNI_PlaySound(Params, Params.Audio.Tones(1));
                end
                SCNI_SendEventCode('Trial_Start', Params);                   	% Send event code to connected neurophys systems
                TargetLocs      = Params.GF.Design(:,Params.Run.TrialCount);    
                CorrectTarget   = TargetLocs(1);
                TargetColorIndx = 1;
                frame           = 1;
                
                GazeCentroid            = Params.Display.Rect([3,4])/2; 
                CorrectTargetCenter     = Params.GF.TargetCenterPix(CorrectTarget, :);
                CorrectTargetRect       = CenterRectOnPoint(Params.GF.TargetRect, CorrectTargetCenter(1), CorrectTargetCenter(2));
                Params.Eye.GazeRect     = Params.GF.GazeFixRect;
                Params.GF.GazeRect      = Params.GF.GazeFixRect;
                
            case 2      %================== Targets appear
                
                
            case 3      %================== Cue appears
                
                
            case 4      %================== Response window begins
                ValidFixProp = nanmean(Params.Run.ValidFixations(Params.Run.TrialCount,:,3));   % Check whether adequate central fixation was maintained
                if ValidFixProp < 0.7
                    EndTrial = 1;   % <<<<<< MAKE THIS DO SOMETHING!
                end
                Params.GF.GazeRect  = CorrectTargetRect;    
                Params.Eye.GazeRect = CorrectTargetRect;
                GazeCentroid        = CorrectTargetCenter;
                
            case 5      %================== Feedback given and avatar resets
                ValidFixProp = nanmean(Params.Run.ValidFixations(Params.Run.TrialCount,:,3));   % <<<< More accurate method needed?
                if ValidFixProp > 0.7
                    TrialCorrect    = 1;
                else
                    TrialCorrect    = 0;
                end
                if TrialCorrect == 1
                    TargetColorIndx     = 2;
                elseif TrialCorrect == 0
                    TargetColorIndx     = 3;
                end
                
            case 6      %================== ITI and reward delivery
                
                
                
        end
        
        
        while (GetSecs - Params.GF.StageTransTime) < Params.GF.TrialStageDur(TrialStage) && Params.Run.ExpQuit == 0

            %=============== Draw stimulus components to both screens  
             
            %=============== Draw background image
            switch Params.GF.BckgrndType
                case 1
                    Screen('FillRect', Params.Display.win, Params.Display.Exp.BackgroundColor*255);                                             % Clear previous frame
                case 2
                    Screen('DrawTexture', Params.Display.win, Params.GF.BckgrndTex, Params.GF.SourceRectExp, Params.GF.RectExp);   
                    Screen('DrawTexture', Params.Display.win, Params.GF.BckgrndTex, Params.GF.SourceRectMonk, Params.GF.RectMonk);
                case 3

            end
            %============ Draw avatar
            if Params.GF.Mode > 1
                Screen('DrawTexture', Params.Display.win, Params.GF.AvatarTex(CorrectTarget,frame), Params.GF.SourceRectExp, Params.GF.RectExp, [], [], Params.GF.Contrast);        % Draw to the experimenter's display
                Screen('DrawTexture', Params.Display.win, Params.GF.AvatarTex(CorrectTarget,frame), Params.GF.SourceRectMonk, Params.GF.RectMonk, [], [], Params.GF.Contrast);      % Draw to the subject's display
            end
            %============ Draw target objects
            if ismember(TrialStage, [2,3,4,5])
                for t = 1:numel(TargetLocs)
                    if t == 1
                    	T = TargetColorIndx;
                    else
                        T = 1;
                    end
                    Screen('DrawTexture', Params.Display.win, Params.GF.TargetTex(T, TargetLocs(t)), Params.GF.SourceRectExp, Params.GF.RectExp); 
                    Screen('DrawTexture', Params.Display.win, Params.GF.TargetTex(T, TargetLocs(t)), Params.GF.SourceRectMonk, Params.GF.RectMonk); 
                end
            end
            
           	for Eye = 1:NoEyes 
                %============ Draw photodiode markers
                if Params.Display.PD.Position > 1
                    PDstatus = ismember(TrialStage, [2,3,4])+1;
                    Screen('FillOval', Params.Display.win, PhotodiodeColor, Params.Display.PD.SubRect(Eye,:));
                    Screen('FillOval', Params.Display.win, PhotodiodeColor, Params.Display.PD.ExpRect);
                end
                %============ Draw fixation marker
                if ismember(TrialStage, [1,2,3]) && Params.GF.FixType > 1
                    Screen('DrawTexture', Params.Display.win, Params.GF.FixTex, [], Params.Display.FixRectMonk(Eye,:));         % Draw fixation marker
                end
            end


            %=============== Check current eye position
            Eye             = SCNI_GetEyePos(Params);                                                           % Get screen coordinates of current gaze position (pixels)
            EyeRect         = repmat(round(Eye(Params.Eye.EyeToUse).Pixels),[1,2])+[-10,-10,10,10];             % Get screen coordinates of current gaze position (pixels)
            [FixIn, FixDist]= SCNI_IsInFixWin(Eye(Params.Eye.EyeToUse).Pixels, GazeCentroid, [], Params);      	% Check if gaze position is inside fixation window

            %=============== Check whether to abort trial
            ValidFixNans 	= find(isnan(Params.Run.ValidFixations(Params.Run.TrialCount,:,1)), 1);             % Find first NaN elements in fix vector
            Params.Run.ValidFixations(Params.Run.TrialCount, ValidFixNans,:) = [GetSecs, FixDist, FixIn];       % Save current fixation result to matrix
         	%Params       	= SCNI_CheckReward(Params);                                                          

            %=============== Draw experimenter's overlay
            if Params.Display.Exp.GridOn == 1
                Screen('FrameOval', Params.Display.win, Params.Display.Exp.GridColor*255, Params.Display.Grid.Bullseye, Params.Display.Grid.BullsEyeWidth);                % Draw grid lines
                Screen('FrameOval', Params.Display.win, Params.Display.Exp.GridColor*255, Params.Display.Grid.Bullseye(:,2:2:end), Params.Display.Grid.BullsEyeWidth+2);   % Draw even lines thicker
                Screen('DrawLines', Params.Display.win, Params.Display.Grid.Meridians, 1, Params.Display.Exp.GridColor*255);                
            end

        	Screen('FrameOval', Params.Display.win, Params.Display.Exp.GazeWinColor(FixIn+1,:)*255, Params.GF.GazeRect, 3); 	% Draw border of gaze window that subject must fixate within
            if Eye(Params.Eye.EyeToUse).Pixels(1) < Params.Display.Rect(3)
                Screen('FillOval', Params.Display.win, Params.Display.Exp.EyeColor(FixIn+1,:)*255, EyeRect);        % Draw current gaze position
            end
            if ismember(TrialStage, [1,2,3]) && Params.GF.FixType > 1
                Screen('DrawTexture', Params.Display.win, Params.GF.FixTex, [], Params.Display.FixRectExp);         % Draw fixation marker
            end
            Params       	= SCNI_UpdateStats(Params); 
            
            %=============== Draw to screen and record time
            [~,FrameOnset]  	= Screen('Flip', Params.Display.win); 
            if NewStage == 1
                switch TrialStage 
                    case 1
                        SCNI_SendEventCode('Fix_On', Params);
                        
                    case 2
                        %SCNI_SendEventCode('Target_On', Params);  
                        
                    case 3
                        %SCNI_SendEventCode('Cue_On', Params); 
                        
                    case 4
                        %SCNI_SendEventCode('Fix_Off', Params); 
                        
                    case 5
                        %SCNI_SendEventCode('Target_Off', Params); 
                        
                end
                NewStage = 0;
            end
            
            %=============== Check experimenter's input
            Params.Run.ExpQuit = CheckKeys(Params);                                                     % Check for keyboard input
            if isfield(Params.Toolbar,'StopButton') && get(Params.Toolbar.StopButton,'value')==1     	% Check for toolbar input
                Params.Run.ExpQuit = 1;
            end
            %=============== Advance frame
            if TrialStage == 3 && frame < size(Params.GF.AvatarTex,2)
                frame = frame+1;
            end
            if TrialStage == 5 && frame > 1
                frame = frame-1;
            end
        end

    end
    
    %% ================= ANALYSE FIXATION FOR WHOLE TRIAL
    %Params = SCNI_CheckTrialEyePos(Params);
              
    if Params.GF.UseAudioCue == 1
        Params 	= SCNI_PlaySound(Params, Params.Audio.Tones(~TrialCorrect + 1));
    end
    
    Params.Run.TrialCount = Params.Run.TrialCount+1;        % Count as one trial
    
end


%============== Run was aborted by experimenter
if Params.Run.ExpQuit == 1
    

end
    
SCNI_SendEventCode('Block_End', Params);   
SCNI_EndRun(Params);
 

end

%=============== CHECK FOR EXPERIMENTER INPUT
function EndRun = CheckKeys(Params)
    EndRun = 0;
    [keyIsDown,secs,keyCode] = KbCheck([], Params.GF.KeysList);                 % Check keyboard for relevant key presses 
    if keyIsDown && secs > Params.Run.LastPress+0.1                           	% If key is pressed and it's more than 100ms since last key press...
        Params.Run.LastPress   = secs;                                        	% Log time of current key press
        if keyCode(Params.GF.Keys.Stop) == 1                                    % Experimenter pressed quit key
            SCNI_SendEventCode('ExpAborted', Params);                         	% Inform neurophys. system
            SCNI_EndRun(Params);
            EndRun = 1;
        elseif keyCode(Params.GF.Keys.Reward) == 1                          	% Experimenter pressed manual reward key
            Params = SCNI_GiveReward(Params);
        elseif keyCode(Params.GF.Keys.Audio) == 1                               % Experimenter pressed play sound key
            Params = SCNI_PlaySound(Params);                
        elseif keyCode(Params.GF.Keys.CenterEyes) == 1
            Params = SCNI_UpdateCenter(Params);     
        end
    end
end

%=============== UPDATE CENTER GAZE POSITION
function Params = SCNI_UpdateCenter(Params)
    Eye         = SCNI_GetEyePos(Params);                                   % Get screen coordinates of current gaze position (pixels)
    Params.Eye.Cal.Offset{Params.Eye.EyeToUse}  =  -Eye(Params.Eye.EyeToUse).Volts;
end

%=============== END RUN
function SCNI_EndRun(Params)
    switch Params.GF.BckgrndType
        case 1
            Screen('FillRect', Params.Display.win, Params.Display.Exp.BackgroundColor*255);                                             % Clear previous frame
        case 2
            Screen('DrawTexture', Params.Display.win, Params.GF.BckgrndTex, Params.GF.SourceRectExp, Params.GF.RectExp);   
            Screen('DrawTexture', Params.Display.win, Params.GF.BckgrndTex, Params.GF.SourceRectMonk, Params.GF.RectMonk);
        case 3

    end
    Screen('Flip', Params.Display.win); 
    return;
end

%=============== PREALLOCATE RANDOMIZED DESIGN
function Params = GenerateGFDesign(Params)

    switch Params.GF.Stim.TargetLayout
        case 'circular'
            TotalLocations  = Params.GF.Stim.NoPolarAngles*Params.GF.Stim.NoEccentricities;
            MinAngle        = 360/Params.GF.Stim.NoPolarAngles;

            % Calculate all pairwise distances in polar angle from avatar
%             for n = 1:TotalLocations
%                 for m = 1:TotalLocations
%                     if n==m
%                         DistMatrix(n,m) = NaN;
%                     else
%                         Pos1 = (n-1)*MinAngle * Params.GF.Stim.TargetDepth;
%                         Pos2 = (m-1)*MinAngle;
%                         DistMatrix(n,m) = abs(Pos1-Pos2);
%                     end
%                 end
%             end
            
            Params.GF.Design    = randi(TotalLocations, [Params.GF.NoTargets, Params.GF.TrialsPerRun]);
            Duplicates          = find(Params.GF.Design(1,:)==Params.GF.Design(2,:));
            while ~isempty(Duplicates)
                Params.GF.Design(2,Duplicates) = randi(TotalLocations, [1, numel(Duplicates)]);
                Duplicates          = find(Params.GF.Design(1,:)==Params.GF.Design(2,:));
            end
                

        case 'linear'



    end

end

%=============== PREALLOCATE RANDOMIZATIONS
function Params	= AllocateRand(Params)
    NoStim = Params.GF.StagesPerTrial*Params.GF.TrialsPerRun;
    if Params.GF.ISIjitter ~= 0
        Params.Run.ISIjitter = ((rand([1,NoStim])*2)-1)*Params.GF.ISIjitter/10^3;
    end
    if Params.GF.PosJitter ~= 0
        Params.Run.PosJitter = ((rand([2,NoStim])*2)-1)'.*Params.GF.PosJitter.*Params.Display.PixPerDeg;
    end
    if Params.GF.ScaleJitter ~= 0
    	Params.Run.ScaleJitter = ((rand([1,NoStim])*2)-1)*Params.GF.ScaleJitter;
    end
end


%================= UPDATE EXPERIMENTER'S DISPLAY STATS
function Params = SCNI_UpdateStats(Params)

    %=============== Initialize experimenter display
    if ~isfield(Params.Run, 'BlockImg')
    	Params.Run.Bar.Length   = 800;                                                                  % Specify length of progress bar (pixels)
        Params.Run.Bar.Labels   = {'Run %','Fix %'};
        Params.Run.Bar.Colors   = {[1,0,0], [0,1,0]};
        Params.Run.Bar.Img      = ones([50,Params.Run.Bar.Length]).*255;                             	% Create blank background image
        Params.Run.Bar.ImgTex 	= Screen('MakeTexture', Params.Display.win, Params.Run.Bar.Img);        % Generate texture handle for block design image
        for p = 10:10:90
            PercRect = [0, 0, p/100*Params.Run.Bar.Length, size(Params.Run.Bar.Img,1)]; 
        	Screen('FrameRect',Params.Run.Bar.ImgTex, [0.5,0.5,0.5]*255, PercRect, 2);
        end
        for B = 1:numel(Params.Run.Bar.Labels)
            Params.Run.Bar.TextRect{B}  = [20, Params.Display.Rect(4)-(B*100)];
            Params.Run.Bar.Rect{B}      = [200, Params.Display.Rect(4)-(B*100)-50, 200+Params.Run.Bar.Length, Params.Display.Rect(4)-(B*100)]; % Specify onscreen position to draw block design
            Params.Run.Bar.Overlay{B}   = zeros(size(Params.Run.Bar.Img));                              
            for ch = 1:3                                                                                
                Params.Run.Bar.Overlay{B}(:,:,ch) = Params.Run.Bar.Colors{B}(ch)*255;
            end
            Params.Run.Bar.Overlay{B}(:,:,4) = 0.5*255;                                               	% Set progress bar overlay opacity (0-255)
            Params.Run.Bar.ProgTex{B}  = Screen('MakeTexture', Params.Display.win, Params.Run.Bar.Overlay{B});            	% Create a texture handle for overlay
        end
        
        Params.Run.TextFormat    = ['Run             %d\n\n',...
                                    'Trial #         %d / %d\n\n',...
                                    'Stage #         %d / %d\n\n',...
                                    'Time elapsed    %02d:%02.0f\n\n',...
                                    'Reward count    %d\n\n',...
                                    'Valid fixation  %.0f %%'];
        if Params.Display.Rect(3) > 1920
           Screen('TextSize', Params.Display.win, 40);
           Screen('TextFont', Params.Display.win, 'Courier');
        end
    end

	Params.Run.ValidFixPercent = nanmean(nanmean(Params.Run.ValidFixations(1:Params.Run.TrialCount,:,3)))*100;

    %========= Update clock
	Params.Run.CurrentTime      = GetSecs-Params.Run.StartTime;                                            % Calulate time elapsed
    Params.Run.CurrentMins      = floor(Params.Run.CurrentTime/60);                    
    Params.Run.CurrentSecs      = rem(Params.Run.CurrentTime, 60);
    Params.Run.CurrentPercent   = (Params.Run.TrialCount/Params.GF.TrialsPerRun)*100;
	Params.Run.TextContent      = [Params.Run.Number, Params.Run.TrialCount, Params.GF.TrialsPerRun, Params.Run.CurrentTrialStage, Params.GF.StagesPerTrial, Params.Run.CurrentMins, Params.Run.CurrentSecs, Params.Reward.RunCount, Params.Run.ValidFixPercent];
    Params.Run.TextString       = sprintf(Params.Run.TextFormat, Params.Run.TextContent);

    %========= Update stats bars
    Params.Run.Bar.Prog = {Params.Run.CurrentPercent, Params.Run.ValidFixPercent};
    for B = 1:numel(Params.Run.Bar.Labels)
        Screen('DrawTexture', Params.Display.win, Params.Run.Bar.ImgTex, [], Params.Run.Bar.Rect{B});
        Screen('FrameRect', Params.Display.win, [0,0,0], Params.Run.Bar.Rect{B}, 3);
        if Params.Run.CurrentPercent > 0
            Params.Run.BlockProgLen      = Params.Run.Bar.Length*(Params.Run.Bar.Prog{B}/100);
            Params.Run.BlockProgRect     = [Params.Run.Bar.Rect{B}([1,2]), Params.Run.BlockProgLen+Params.Run.Bar.Rect{B}(1), Params.Run.Bar.Rect{B}(4)];
            Screen('DrawTexture',Params.Display.win, Params.Run.Bar.ProgTex{B}, [], Params.Run.BlockProgRect);
            Screen('FrameRect',Params.Display.win, [0,0,0], Params.Run.BlockProgRect, 3);
            DrawFormattedText(Params.Display.win, Params.Run.Bar.Labels{B}, Params.Run.Bar.TextRect{B}(1), Params.Run.Bar.TextRect{B}(2), Params.Run.TextColor);
        end
    end
    DrawFormattedText(Params.Display.win, Params.Run.TextString, Params.Run.TextRect(1), Params.Run.TextRect(2), Params.Run.TextColor);
end