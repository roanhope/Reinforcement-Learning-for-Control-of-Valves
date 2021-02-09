# Reinforcement-Learning-for-Control-of-Valves
This project uses DDPG for "optimal" control of non-linear valves. Uses MATLAB and Simulink. 

Paper: https://arxiv.org/abs/2012.14668

The paper introduces the use of MATLAB's Reinforcement Learning ToolBox to create "optimal" controllers for non-linear plants such as valves. "Graded Learning" is a simple "coaching" method, that allows one to train an agent much more efficiently. The paper highligths the learnings during the research and links the observations to previously published literature around challenges often experienced when using DDPG and reinforcement learning for optimal control. While the code and paper use Valve as a 'plant', the methods and code is easily adaptable to any industrial plant.

Note that - Graded Learning is the simplest (and application/practise oriented) form of Curriculum Learning. 

[![View Reinforcement Learning for Control of Non-Linear Valves on File Exchange](https://www.mathworks.com/matlabcentral/images/matlab-file-exchange.svg)](https://in.mathworks.com/matlabcentral/fileexchange/87132-reinforcement-learning-for-control-of-non-linear-valves)

TRAINING FILES:
---------------
1. sm_DDPG_Training_Circuit.slx: 	Simulink: Non-linear valve model, DDPG agent controller
2. code_DDPG_Training.m:		MATLAB code: Create a DDPG agent and train using Graded Learning   

EXPERIMENT and VERIFY using trained agent:
------------------------------------------
1. sm_Experimental_Setup.slx:		Simulink: Non-linear valve model, DDPG agent controller. Experiment with noise signals and sources
2. code_Experimental_Setup.m:		MATLAB code: Load trained models of choice and run to see effects on scope
3. sm_PID_Tuning.slx:			Simulink: Tune a PID controller for comparison

STABILITY ANALYSIS:
-------------------
1. code_SA_TF_Estimator.m               MATLAB code: Estimate a Transfer function for the RL controller
2. code_SA_Utilities.m
3. sm_StabilityStudy.slx                Simulink: Model to estimate the transfer function
4. data_SA_TransferFunctions.mat    	Data file: Store the transfer function    
5. data_TransferFunctions_NP3_NZ1.mat   Data file: Store the transfer function (example transfer function with 3 poles and 1 zero)


Please cite as:
```
@misc{siraskar2020reinforcement,
      title={Reinforcement Learning for Control of Valves}, 
      author={Rajesh Siraskar},
      year={2020},
      eprint={2012.14668},
      archivePrefix={arXiv},
      primaryClass={cs.LG}
}
```
