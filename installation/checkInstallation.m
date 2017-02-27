function checkInstallation()
% checkInstallation
%   The purpose of this function is to check if all necessary functions are
%   installed and working

%   Usage: checkInstallation()
%
%	Eduard Kerkhoven, 2016-10-23 - Use Matlab preferences for solver selection
%

fprintf('*** RAVEN TOOLBOX v. 1.9\n');

keepSolver=false;
lastWorking='';

%Check if RAVEN is in the path list
paths=textscan(path,'%s','delimiter', pathsep);
paths=paths{1};

%Get the RAVEN path
[ST I]=dbstack('-completenames');
[ravenDir,crap1,crap2]=fileparts(fileparts(ST(I).file));

% get current solver
if ~ispref('RAVEN','solver')
	fprintf('Solver found in preferences... NONE\n');
else
	curSolv=getpref('RAVEN','solver');
	fprintf(['Solver found in preferences... ',curSolv,'\n']);
end

if ismember(ravenDir,paths)
    fprintf('Checking if RAVEN is in the Matlab path... PASSED\n');
else
    fprintf('Checking if RAVEN is in the Matlab path... FAILED\n');
    addMe=input('\tWould you like to add the RAVEN directory to the path list? Y/N\n','s');
    if strcmpi(addMe,'y')
        subpath=genpath(ravenDir); % Lists all subdirectories
        subpath=regexprep(subpath,['[\\\/].git[a-zA-Z_0-9\\\/]*;'],';'); % Remove \.git and subfolders
        subpath=[strrep(subpath,[ravenDir ';'],'') ravenDir]; % Remove remnants of .git subfolders and add ravenDir
        addpath(subpath);
        savepath
    end
end

excelFile=fullfile(ravenDir,'tutorial','empty.xlsx');
xmlFile=fullfile(ravenDir,'tutorial','empty.xml');

%Check if it is possible to parse an Excel file
try
    importExcelModel(excelFile,false,false,true);
    fprintf('Checking if it is possible to parse a model in Microsoft Excel format... PASSED\n');
catch
    fprintf('Checking if it is possible to parse a model in Microsoft Excel format... FAILED\n');
    if ispc==false %Print info for UNIX/MacOS
        fprintf('\tThis functionality uses Microsoft Excel COM server, which works best for the Windows version of Matlab\n');
    end
end

%Check if it is possible to import an SBML model using libSBML
try
    smallModel=importModel(xmlFile);
    fprintf('Checking if it is possible to import an SBML model using libSBML... PASSED\n');
catch
    fprintf('Checking if it is possible to import an SBML model using libSBML... FAILED\n');
end

%Check if it is possible to solve an LP problem using different solvers
solver={'mosek','gurobi'};

for i=[1:numel(solver)]
    try
        setRavenSolver(solver{i});
        solveLP(smallModel);
        lastWorking=solver{i};
        fprintf(['Checking if it is possible to solve an LP problem using ',solver{i},'... PASSED\n']);
        if and(exist('curSolv','var'),strcmp(curSolv,solver{i}))
            keepSolver=true;
        end
    catch
        fprintf(['Checking if it is possible to solve an LP problem using ',solver{i},'... FAILED\n']);
    end
end

if keepSolver
    setRavenSolver(curSolv);
elseif ~isempty(lastWorking)
    setRavenSolver(lastWorking);
end

if ~exist('curSolv','var')
	fprintf(['Prefered solver... NEW\nSolver saved as preference... ',lastWorking,'\n']);
elseif keepSolver
	fprintf(['Prefered solver... KEPT\nSolver saved as preference... ',curSolv,'\n']);
else
	fprintf(['Prefered solver... CHANGED\nSolver saved as preference... ',lastWorking,'\n']);
end

%function lastWorking=checkSolver(solver)
