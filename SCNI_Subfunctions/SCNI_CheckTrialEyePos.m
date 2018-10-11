function Params = SCNI_CheckTrialEyePos(Params)

%======================== SCNI_CheckTrialEyePos.m =========================
% This function reads all analog eye position data for the current trial
% period from DataPixx2 and assesses whether fixation requirements were met
% in order to determine appropriate feedback.
%==========================================================================


%=============== READ ANALOG INPUT DATA
Datapixx('RegWrRd');                                                                        % Update registers for GetAdcStatus
status          = Datapixx('GetAdcStatus');                                              
nReadSpls       = status.newBufferFrames;                                                 	% How many samples can we read?
[NewData, NewDataTs] = Datapixx('ReadAdcBuffer', nReadSpls, Params.DPx.adcBuffBaseAddr); 	% Read all available samples from ADCs
Datapixx('StopAdcSchedule');                                                                % Stop current schedule
EyeChannels     = [Params.Eye.XYchannels{Params.Eye.EyeToUse}, Params.Eye.XYchannels{Params.Eye.EyeToUse}(2)+1];
EyeData         = NewData(EyeChannels,:);   
DiodeChannel    = find(~cellfun(@isempty, strfind(Params.DPx.AnalogIn.Labels, 'Photodiode')))+1;
DiodeData       = NewData(DiodeChannel,:);
Timestamps      = linspace(0, numel(DiodeData)/Params.DPx.AnalogInRate, numel(DiodeData));  % Analog data timestamps (seconds)

for xy = 1:2                                                                                % Convert eye position voltages to degrees
    EyeDataDVA(xy,:)    = (EyeData(xy,:) + Params.Eye.Cal.Offset{Params.Eye.EyeToUse}(xy))*Params.Eye.Cal.Gain{Params.Eye.EyeToUse}(xy); % Convert volts into degrees of visual angle
    EyeDataPix(xy,:)    = EyeDataDVA(xy,:)*Params.Display.PixPerDeg(xy);
end
StimOnsetSamples      = find(diff(DiodeData) > 1)+1;                                    	% Find photodiode onset samples
StimOffsetSamples     = find(diff(DiodeData) < -1);                                         % Find photodiode offset samples
StimOnsetSamples(find(diff(StimOnsetSamples)==1)+1) =[];                                    % Remove consecutive samples
StimOffsetSamples(find(diff(StimOffsetSamples)==1)+1) =[];                      

if numel(StimOnsetSamples) ~= Params.Eye.StimPerTrial
    fprintf('Warning: number of detected photiode onsets (%d) does not match expected number of stimuli per trials (%d)!\n', numel(StimOnsetSamples), Params.Eye.StimPerTrial);
    plot(DiodeData);
end
if numel(StimOffsetSamples) < numel(StimOnsetSamples)
    StimOffsetSamples(end+1) = numel(Timestamps);
end

%=============== GET STIMULUS LOCATIONS
if Params.Eye.CenterOnly == 1
    LocIndices     = repmat(find(ismember(Params.Eye.Target.FixLocDirections,[0,0],'rows')), [1, Params.Eye.StimPerTrial]);
elseif Params.Eye.CenterOnly == 0
    LocIndices     = Params.Eye.Target.LocationOrder((Params.Run.StimCount-Params.Eye.StimPerTrial):(Params.Run.StimCount-1));
end
for stim = 1:Params.Eye.StimPerTrial 
    Samples         = StimOnsetSamples(stim):StimOffsetSamples(stim); 
    GazeRect        = Params.Eye.Target.GazeRect{LocIndices(stim)};
    InRect          = (EyeDataPix(1,Samples) >= GazeRect(RectLeft) & EyeDataPix(1,Samples) <= GazeRect(RectRight) & ...
                        EyeDataPix(2,Samples) >= GazeRect(RectTop) & EyeDataPix(2,Samples) <= GazeRect(RectBottom));
    PropFix(stim)   = sum(InRect)/numel(InRect);
        
%   	EyeOffset(1,:)  = EyeDataPix(1,Samples) - repmat(Params.Eye.Target.FixLocationsDeg(LocIndices(Stim),1),[1, size(EyeDataDVA, 2)]);
%     EyeOffset(2,:)  = EyeDataPix(2,Samples) - repmat(Params.Eye.Target.FixLocationsDeg(LocIndices(Stim),2),[1, size(EyeDataDVA, 2)]);
end
% Dists           = sqrt(EyeOffset(1,:).^2 + EyeOffset(2,:).^2);       	% Calculate gaze distance from center of screen (degrees)
% InFix           = zeros(1, numel(Dists));                           	% Preallocate vector
% InFix(find(Dists <= mean(Params.Eye.FixDist))) = 1;                     % If gaze was within specified radius, code as 1    
% ProportionIn    = numel(find(InFix==1))/numel(InFix);                   % Calculate proportion of samples that gaze position was within fixation window
% FixAbsentSmpls  = numel(find(InFix==0));

if mean(PropFix) < Params.Eye.FixPercent/100                         	% If total fixation duration percentage was less than required...
    Params.Run.ValidTrial = 0;                                       	% Invalid trial!
elseif mean(PropFix) >= Params.Eye.FixPercent/100   
    Params.Run.ValidTrial = 1;                                         	% Valid trial!
end

end