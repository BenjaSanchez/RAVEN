function out = setRavenSolver(solver,saveSolver)
% setRavenSolver
%   Sets the solver for RAVEN and optionally saves a default value
%	to MATLAB startup.
%
%   solver		a string ('gurobi','mosek', ...)
%   saveSolver	option to save the choice as default to startup.m
%
%   Usage: setRavenSolver('gurobi',true)
%
%   Daniel Hermansson, 2016-10-10

	if nargin<2
		saveSolver='none';
	end

	if (~ischar(solver)) dispEM('Input should be a string.'); end
	
	if (isempty(userpath))
		userpath('reset')
	end
	
	up=pathdef;
	up=regexp(up,':','split');
	up=up{1};

	% copy setRavenSolver to userpath	
	if (exist(fullfile(up,'setRavenSolver.m'), 'file') ~= 2)
		p = mfilename('fullpath');
		copyfile([p,'.m'],up);
	end

	global RAVENSOLVER;
	RAVENSOLVER=solver;

	try
		ravenSet=false;
		startupInd=1;

		% Read txt into cell
		lines = regexp( fileread(fullfile(up,'startup.m')), '\n', 'split');
		for i = 1:numel(lines)
			if (regexp(lines{i},'setRavenSolver('))
				ravenSet=true;
				startupInd=i;
			end
		end
	catch Ex
		%
	end

	if (~saveSolver) return; end

	% if we reached this far we are interested in saving the choice to startup
	if (~ravenSet && strcmp(saveSolver,'none'))
		m=input(['You have no default RAVEN solver defined. Should we append ', solver ,' to MATLAB startup? y/n [y]: '],'s');
		if (m=='n') return; end
	end
	
	try
		if (ravenSet)
			fid = fopen(fullfile(up,'startup.m'),'w');
			lines{startupInd} = sprintf('setRavenSolver(''%s'');', solver);

			% Write cell into txt
			for i = 1:numel(lines)
		        if (~strcmp(lines{i},'')) fprintf(fid,'%s\n', lines{i}); end
			end
		else
			fid = fopen(fullfile(up,'startup.m'),'a+');
			fprintf(fid,'\nsetRavenSolver(''%s'');\n', solver);
		end
	catch Ex
		if (fid~=-1) fclose(fid); end
		dispEM('Could not save to startup.m');
	end

	if (fid~=-1) fclose(fid); end
end