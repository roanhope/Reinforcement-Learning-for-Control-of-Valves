%--------------------------------------------------------------------------
% Reinforcement Learning for Valve Control
% -------------------------------------------------------------------------
% The follow code accompanies the paper titled "Reinforcement Learning for Control of Valves"
% https://arxiv.org/abs/2012.14668
% The paper explores RL for optimum control of non-linear systems. 
% It uses the DDPG (Deep Deterministic Policy-Gradient) algorithm to control a non-linear valve modelled based on 
%   the paper by di Capaci and Scali (2018), "An augmented PID control structure to compensate for valve stiction"
%
% The paper explores "Graded Learning" to assist in efficiently training an RL agent. We decompose the training 
% task into simpler objectives and train the agent in stages. These parameters will be based on your process and plant. 
% To follow the paper and code, we use the following:
% (1) An "industrial" process modelled using a first-order plus time-delay (FOPTD) transfer-function of the form 
%  		G(s) = k * exp(-L.s) / (1 + T.s)
% 		where k = 3.8163, T = 156.46 and L is the time-delay parameter = 2.5
% (2) A non-linear valve modelled based on (di Capaci and Scali, 2018), characterized by two parameters:
%		Static friction or stiction: fS = 8.4
%		Dynamic friction: fD = 3.5243
% 
% -------------------------------------------------------------------------
% Code description:
% -------------------------------------------------------------------------
%
% Set the following global variables before trying:
% - BASE_PATH: Points to your base path for storing the models (currently set to 'D:/RLVC/models/')
% - VERSION: Version suffix for your model, say "V1", or "Grade-1" etc. 
%
% Next set the  Graded Learning parameters
% Graded Learning: We trained the agent in SIX stages (Grade-I to Grade-VI) by successively increasing the difficulty 
%  of the task. The parameters will be based on your process and plant. For this code, we used the following:
% (1) TIME_DELAY = Time-delay parameter (L) of the FOPTD process. Set as 0.1, 0.5, 1.5, 2.0 and 2.5
% (2) fS = Non-linear valve stiction. We use the following stages 1/10th of 8.5, followed by 1/5th, 1/2, 2/3 and
% 		   finally full 8.4
% (3) fD = Non-linear valve dynamic friction. We used the same fractions as above for fS for fD, finally ending 
%		   with the actual value of 3.5243
%
%
%
% Graded Learning Stages:
% GRADE_I:    TIME_DELAY=0.1; fS = 8.4/10; fD = 3.5243/10 
% GRADE_II:   TIME_DELAY=0.5; fS = 8.4/5; fD = 3.5243/5
% GRADE_III:  TIME_DELAY=1.5; fS = 8.4/2; fD = 3.5243/2
% GRADE_IV:   TIME_DELAY=1.5; fS = 8.4/1.5; fD = 3.5243/1.5
% GRADE_V:    TIME_DELAY=2.0, fS/1.5 and fD/1.5
% GRADE_VI:   TIME_DELAY=2.5, fS/1.0 and fD/1.0
%--------------------------------------------------------------------------

clear all;
tstart= datetime();
BASE_PATH = 'D:/RLVC/models/'

VERSION = 'Grade_VI';
% GRADED LEARNING PARAMETERS
TIME_DELAY = 2.0;

SAVE_AGENT_THRESHOLD = 700; 
STOP_TRAINING = 730;
MAX_REWARD = STOP_TRAINING;
VALVE_SIMULATION_MODEL = 'sm_DDPG_Training_Circuit';

% For Transfer Learning provide the model to continue learning on
TRAINING_MODE = true;
USE_PRE_TRAINED_MODEL = true;
PRE_TRAINED_MODEL_FILE = '/TestModels/Grade_IV_ver.3_600.mat';

% Epsiode and time related
MAX_EPISODES = 1000;
Ts = 1.0;   % Ts: Sample time (secs)
Tf = 150;   % Tf: Simulation length (secs)

AVERAGE_WINDOW = 50;        % Average over 50 episodes of 150 each
ACCEPTABLE_DELTA = 0.05;

% DDPG Hyper-paramaters
criticLearningRate = 1e-03;
actorLearningRate  = 1e-04;
GAMMA = 0.90;
BATCH_SIZE = 64;

% Critic network: Neurons for fully-connected Observsation (state) and Action paths 
neuronsOP_FC1 = 50; neuronsOP_FC2 = 25; neuronsAP_FC1 = 25;

date_today = datetime();
RL_MODEL_PATH = strcat(BASE_PATH, VERSION, '/');
RL_AGENT = strcat(VALVE_SIMULATION_MODEL, '/RL Sub-System/RL Agent');
RL_MODEL_FILE = strcat(RL_MODEL_PATH, 'RL_Model_DDPG_V', VERSION, '.mat');

obsInfo = rlNumericSpec([3 1],...
    'LowerLimit',[-inf -inf 0]',...
    'UpperLimit',[ inf  inf inf]');
obsInfo.Name = 'observations';
obsInfo.Description = 'controlled flow, error, integral of error';
numObservations = obsInfo.Dimension(1);

actInfo = rlNumericSpec([1 1]);
actInfo.Name = 'flow';
numActions = numel(actInfo);

env = rlSimulinkEnv(VALVE_SIMULATION_MODEL, RL_AGENT, obsInfo, actInfo);

% Reset function
env.ResetFcn = @(in)localResetFcn(in, VALVE_SIMULATION_MODEL);
% rng(0);

% Create DDPG agent neuronsOP_FC1 = 50; neuronsOP_FC2 = 25; neuronsAP_FC1 = 25;
statePath = [
    imageInputLayer([numObservations 1 1], 'Normalization', 'none', 'Name', 'State')
    fullyConnectedLayer(neuronsOP_FC1, 'Name', 'CriticStateFC1')
    reluLayer('Name', 'CriticRelu1')
    fullyConnectedLayer(neuronsOP_FC2, 'Name', 'CriticStateFC2')];
actionPath = [
    imageInputLayer([numActions 1 1], 'Normalization', 'none', 'Name', 'Action')
    fullyConnectedLayer(neuronsAP_FC1, 'Name', 'CriticActionFC1')];
commonPath = [
    additionLayer(2,'Name', 'add')
    reluLayer('Name','CriticCommonRelu')
    fullyConnectedLayer(1, 'Name', 'CriticOutput')];

% Critic network
criticNetwork = layerGraph();
criticNetwork = addLayers(criticNetwork,statePath);
criticNetwork = addLayers(criticNetwork,actionPath);
criticNetwork = addLayers(criticNetwork,commonPath);
criticNetwork = connectLayers(criticNetwork,'CriticStateFC2','add/in1');
criticNetwork = connectLayers(criticNetwork,'CriticActionFC1','add/in2');
                  
criticOpts = rlRepresentationOptions('LearnRate', criticLearningRate, 'GradientThreshold',1);

critic = rlRepresentation(criticNetwork,obsInfo,actInfo,'Observation',...
    {'State'},'Action',{'Action'},criticOpts);

actorNetwork = [
    imageInputLayer([numObservations 1 1], 'Normalization', 'none', 'Name', 'State')
    fullyConnectedLayer(3, 'Name', 'actorFC')
    tanhLayer('Name', 'actorTanh')
    fullyConnectedLayer(numActions, 'Name', 'Action')
    ];

actorOptions = rlRepresentationOptions('LearnRate',actorLearningRate,'GradientThreshold',1);

actor = rlRepresentation(actorNetwork,obsInfo,actInfo,'Observation',{'State'},'Action',{'Action'},actorOptions);

agentOpts = rlDDPGAgentOptions(...
    'SampleTime', Ts,...
    'TargetSmoothFactor', 1e-3,...
    'DiscountFactor', GAMMA, ...
    'MiniBatchSize', BATCH_SIZE, ...
    'ExperienceBufferLength', 1e6, ...
    'ResetExperienceBufferBeforeTraining', false, ...
    'SaveExperienceBufferWithAgent', false); 

% Exploration Parameters
% ----------------------
% Ornstein Uhlenbeck (OU) action noise:
%   Variance*sqrt(SampleTime) keep between 1% and 10% of your action range
% Variance is halved by these many samples: 
%       halflife = log(0.5)/log(1-VarianceDecayRate)
% Default: 0.45, 1e-5
DDPG_Variance = 1.5;
DDPG_VarianceDecayRate = 1e-5; % Half-life of 1,000 episodes
% agentOpts.NoiseOptions.Variance = DDPG_Variance;
% agentOpts.NoiseOptions.VarianceDecayRate = DDPG_VarianceDecayRate; 

agent = rlDDPGAgent(actor, critic, agentOpts);

maxepisodes = MAX_EPISODES;
maxsteps = ceil(Tf/Ts);

% For parallel computing: 'UseParallel',true, ...
criticOptions.UseDevice = 'gpu';

% To enable save
trainOpts = rlTrainingOptions(...
    'MaxEpisodes', maxepisodes, ...
    'MaxStepsPerEpisode', maxsteps, ...
    'ScoreAveragingWindowLength', AVERAGE_WINDOW, ...
    'Verbose', false, ...
    'Plots','training-progress',...
    'SaveAgentDirectory', RL_MODEL_PATH, ...
    'SaveAgentValue', SAVE_AGENT_THRESHOLD, ...
    'SaveAgentCriteria','AverageReward', ...
    'StopTrainingCriteria','AverageReward',...
    'StopTrainingValue', STOP_TRAINING);

% To plot network architectures
% Show neural network architecture
% actorNet = getModel(getActor(agent));
% criticNet = getModel(getCritic(agent));
% plot(actorNet); title("Actor Network");
% plot(criticNet); title("Critic Network");
% % Print parameters
% actorNet; actorNet.Layers;
% % Print parameters
% criticNet; criticNet.Layers;

if USE_PRE_TRAINED_MODEL    
    % Load experiences from pre-trained agent    
    sprintf('- RLVC: Loading pre-trained model: %s', PRE_TRAINED_MODEL_FILE)
    RL_MODEL_FILE = strcat(BASE_PATH, PRE_TRAINED_MODEL_FILE);                
    load(RL_MODEL_FILE,'agent');
    % agent = saved_agent;
else
    agent = rlDDPGAgent(actor, critic, agentOpts);
end

% Train the agent or Load a pre-trained model and run in Suimulink
if TRAINING_MODE
    sprintf ('\n\n ==== RLVC: AGENT TRAINING ============================================================\n---- Ver.: %s, Time-Delay: %3.2f\n', VERSION, TIME_DELAY)
    if (USE_PRE_TRAINED_MODEL)
        sprintf (' ------ Transfer Learning enabled: %s', PRE_TRAINED_MODEL_FILE)
    end
    % Train the agent
    trainingStats = train(agent, env, trainOpts);
    % Save agent
    nEpisodes = length(trainingStats.EpisodeIndex);
    fname = strcat(RL_MODEL_PATH, VERSION, '_', int2str(nEpisodes), '.mat');
    sprintf ('Saving file: %s', fname)
    save(fname, "agent");
    display("End training: ") 
    tend = datetime();
else        
    % Validate the learned agent against the model by simulation
    simOpts = rlSimulationOptions('MaxSteps', 2000, 'StopOnError','on');
    experiences = sim(env, saved_agent, simOpts);
end

display("Elapsed time:")
telapsed = tend - tstart;
telapsed

% ------------------------------------------------------------------------
% Environment Reset function 
% - Reset if the controlled speed drops to zero or negative or > 15
% Ver 7.3 Limit to Capaci paper levels 
% ------------------------------------------------------------------------
function in = localResetFcn(in, RL_System)
    % -------------------------------------------------------------
    % GENERIC TRAINING SIGNALs
    % Randomize Reference_Signal between 0 and 100
    % -------------------------------------------------------------
    block_Reference_Signal = strcat (RL_System, '/Reference_Signal');
    Reference_Signal = 20+randi(80) + rand;
    in = setBlockParameter(in, block_Reference_Signal, ...
        'Value', num2str(Reference_Signal));

    % Randomize initial condition of the flow (0 and 100) 
    block_Actual_Flow = strcat (RL_System, '/Plant/Process/FLOW');    
    Actual_Flow = 20+randi(80) + rand;
    in = setBlockParameter(in, block_Actual_Flow, 'Bias', num2str(Actual_Flow));
end

% ------------------------------------------------------------------------
% Run a pre-trained model in Simulink
% ------------------------------------------------------------------------
function RunPreTrainedModel(model_file, agent, env, maxsteps)

    sprintf('- Loading and running %s: ', model_file)
    load(model_file,'agent');

    % Validate the learned agent against the model by simulation
    rlSimulationOptions('MaxSteps', maxsteps, 'StopOnError', 'on');
    experiences = sim(env, agent);
end
