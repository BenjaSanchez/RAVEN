function compStruct=compareMultipleModels(models,printResults,plotResults,groupVector,funcCompare,taskFile)
% compareModels
%   Compares two or more condition-specific models generated from the same
%   base model using high-dimensional comparisons in the reaction-space.
%
%   models              cell array of two or more models
%   printResults        true if the results should be printed on the screen
%                       (opt, default false)
%   plotResults         true if the results should be plotted
%                       (opt, default false)
%   groupVector         numeric vector for grouping similar models, i.e. by
%                       tissue (opt, default, all models ungrouped)
%   funcCompare         logical, should a functional comparison be run
%                       (opt,default, false)
%   taskFile            string containing the name of the task file to use
%                       for the functional comparison (should be an .xls or 
%                       .xlsx file, required for functional comparison)
%
%   compStruct          structure that contains the comparison
%       modelIDs        cell array of model ids
%       reactions       
%           matrix      binary matrix composed of reactions (rows) in each
%                       model (column). This matrix is used as the input for
%                       the model comparisons.
%           IDs        list of the reactions contained in the reaction matrix.
%       subsystems    
%           matrix      table with comparison of number of rxns per
%                       subsystem
%           ID          vector consisting of names of all subsystems
%       structComp      matrix with pairwise comparisons of model structure
%                       based on (1-Hamming distance) between models
%       structCompMap   matrix with 3D tSNE (or MDS) mapping of model structures
%                       based on Hamming distances
%       funcComp
%           matrix      table with PASS / FAIL (1 / 0) values for each task
%           tasks       vector containing names of all tasks
%
%   Usage: compStruct=compareMultipleModels(models,printResults,...
%                       plotResults,groupVector,funcCompare,taskFile);
%   
%   Daniel Cook, 2018-03-16

%% Set up input defaults
if nargin<2
    printResults=false;
end

if nargin<3
    plotResults=false;
end

if nargin<4
    groupVector = [];
end

if nargin<5
    funcCompare = false;
end

if nargin<6
    taskFile = [];
end

if numel(models)<=1
    EM='Cannot compare only one model. Use printModelStats if you want a summary of a model';
    dispEM(EM);
end

if nargin<6 && funcCompare==T
    EM='Cannot perform the functional comparison without a task file. Specify taskFile or set funcCompare to FALSE.';
    dispEM(EM);
end

%% Set up model ID structure
compStruct.modelIDs={};
fprintf('\n Getting model IDs \n')
for i=1:numel(models)
    compStruct.modelIDs=[compStruct.modelIDs;models{i}.id];
end
fprintf('*** Done \n\n')

%% Compare models structure & function based on high-dimensional methods
% Compare number of reactions in each subsystem in each model using a heatmap
field = 'subSystems';
fprintf('\n Comparing subsystem utilization \n')
for i = 1:numel(models)
    field_present(i) = isfield(models{i},field);
end
if sum(field_present) ~= numel(models)
    fprintf('\nWARNING: At least one model does not contain the field "subSystems". \n')
    fprintf('         Skipping subsystem comparison. \n\n')
else
    compStruct.subsystems.ID = catModelElements(models,field);
    compStruct.subsystems.matrix = compareSubsystems(models,field);
    fprintf('*** Done \n\n')
    if printResults==true
        % This could use come cleaning up
        fprintf('*** Comparison of reaction subsystem populations:\n');
        str = [" "];
        for i=1:length(compStruct.modelIDs)
            str(1,i+1) = compStruct.modelIDs{i};
        end
        for i = 1:size(compStruct.subsystems.matrix,1)
            if length(compStruct.subsystems.ID{i}) <= 16
                str(i+1,1) = compStruct.subsystems.ID{i};
            else
                str(i+1,1) = [compStruct.subsystems.ID{i}(1:16) ' ...'];
            end
            for j=1:length(compStruct.modelIDs)
                str(i+1,j+1) = num2str(compStruct.subsystems.matrix(i,j));
            end
        end
        subsystem_comparison = str;
        subsystem_comparison
        fprintf('\n\n');
    end
    if plotResults==true
        % Plot all subsystems
        plottingData = (compStruct.subsystems.matrix - mean(compStruct.subsystems.matrix,2))./mean(compStruct.subsystems.matrix,2);
        color_map = redblue(length(0:.01:2));
        h = genHeatMap(plottingData',compStruct.subsystems.ID,compStruct.modelIDs,'both','euclidean',color_map,[-1,1]);
        title('Subsystem Coverage - all subsystems','FontSize',18,'FontWeight','bold')
        
        % Plot only subsystems with deviation from mean
        h_small = genHeatMap(plottingData(sum(plottingData~=0,2)~=0,:)',compStruct.subsystems.ID(sum(plottingData~=0,2)~=0),...
            compStruct.modelIDs,'both','euclidean',color_map,[-1,1]);
        title('Subsystem Coverage','FontSize',18,'FontWeight','bold')
        
        % Plot enrichment in subsystems with deviation from mean
        color_map_bw = [1 1 1;0 0 0];
        h_enriched = genHeatMap(plottingData(sum(plottingData~=0,2)~=0,:)',compStruct.subsystems.ID(sum(plottingData~=0,2)~=0),...
            compStruct.modelIDs,'both','euclidean',color_map_bw,[-10^-4,10^-4]);  
        title('Subsystem Enrichment','FontSize',18,'FontWeight','bold')
    end
end

% Compare overall reaction structure across all models using a heatmap
field = 'rxns';
fprintf('\n Comparing model reaction correlations \n')
all_rxns = catModelElements(models,field);
% Create binary matrix of reactions
binary_matrix = zeros(length(all_rxns),numel(models));
for i=1:numel(models)
    binary_matrix(:,i) = ismember(all_rxns,models{i}.rxns);
end

% Save results
compStruct.reactions.IDs = all_rxns;
compStruct.reactions.matrix = binary_matrix;
compStruct.structComp = 1-squareform(pdist(binary_matrix','hamming'));

clear color_map
for i = 1:101
    color_map(i,:) = [1 (1-(i-1)/100) (1-(i-1)/100)];
end
fprintf('*** Done \n\n')
if plotResults == true
    h = genHeatMap(compStruct.structComp,compStruct.modelIDs,compStruct.modelIDs,'both','euclidean',color_map,[0,1]);
    title('Structural Similarity','FontSize',18,'FontWeight','bold')
end

% Compare overall reaction structure across all models using tSNE projection
rng(42) % For consistency
fprintf('\n Comparing model reaction structures \n')
if exist('tsne') > 0
    t_vars_3d_struc = tsne(double(binary_matrix'),'Distance','hamming','NumDimensions',3); % 3D
    compStruct.structCompMap = t_vars_3d_struc;
    fprintf('*** Done \n\n')
    if plotResults == true
        figure();hold on; 
        if length(groupVector) > 0
            color_vector = groupVector;
            colormap(parula(max(groupVector)));
        else
            color_vector = 'k';
        end
        scatter3(t_vars_3d_struc(:,1),t_vars_3d_struc(:,2),t_vars_3d_struc(:,3),35,color_vector,'filled')
        xlabel('tSNE 1');ylabel('tSNE 2');zlabel('tSNE 3');set(gca,'FontSize',14,'LineWidth',1.25);
        title('Structural Comparison','FontSize',18,'FontWeight','bold')
        % Need to add legend
    end
else
    fprintf('\nWARNING: Could not complete full structural comparison because the function \n')
    fprintf('         "tsne" does not exist in your Matlab version. \n')
    fprintf('         Using MDS to project data instead of tSNE. \n')
    fprintf('         Please upgrade to Matlab 2017b or higher for full functionality. \n\n')
    [mds_vars_3d_struc,stress,disparities] = mdscale(pdist(double(binary_matrix'),'hamming'),3);
    compStruct.structCompMap = mds_vars_3d_struc;
    if plotResults == true
        figure();hold on; 
        if length(groupVector) > 0
            color_vector = groupVector;
            colormap(parula(max(groupVector)));
        else
            color_vector = 'k';
        end
        scatter3(mds_vars_3d_struc(:,1),mds_vars_3d_struc(:,2),mds_vars_3d_struc(:,3),35,color_vector,'filled')
        xlabel('MDS 1');ylabel('MDS 2');zlabel('MDS 3');set(gca,'FontSize',14,'LineWidth',1.25);
        title('Structural Comparison','FontSize',18,'FontWeight','bold')
    end
end

% Compare model functions by simulating their capacity to perform tasks
if funcCompare == true && ~isempty(taskFile)
    fprintf('\n Checking model performance on specified tasks. \n')
    taskStructure=parseTaskList(taskFile);
    for i = 1:numel(models)
        fprintf('\n Checking model # %.0f \n',i)
        taskReport{i}=checkTasks(models{i},[],false,false,false,taskStructure);
    end    
    
    % Save results
    taskMatrix = zeros(length(taskReport{1}.ok),numel(taskReport));
        for i = 1:numel(taskReport)
            taskMatrix(:,i) = taskReport{i}.ok;
        end
    compStruct.funcComp.matrix = taskMatrix;
    compStruct.funcComp.tasks = taskReport{1}.description;
    fprintf('*** Done \n\n')
   
    % Plot results
    if plotResults == true        
        color_map_bw = [1 1 1;0 0 0];
        h_enriched = genHeatMap(taskMatrix,compStruct.modelIDs,...
            taskReport{1}.description,'both','euclidean',color_map_bw,[0,1]);
        title('Functional Comparison - All Tasks','FontSize',18,'FontWeight','bold')
        
        color_map_bw = [1 1 1;0 0 0];
        h_enriched = genHeatMap(taskMatrix(intersect(find(sum(taskMatrix,2)~=numel(models)),find(sum(taskMatrix,2)~=0)),:),...
            compStruct.modelIDs,taskReport{1}.description(intersect(find(sum(taskMatrix,2)~=numel(models)),find(sum(taskMatrix,2)~=0))),...
            'both','euclidean',color_map_bw,[0,1]);
        title('Functional Similarity','FontSize',18,'FontWeight','bold')
    end
end

end

%% Additional Functions
function A=getElements(models,field)
    A={};
    for i=1:numel(models)
       if isfield(models{i},field)
           A=[A;{models{i}.(field)}];
       end
    end
end

function B = compareSubsystems(models,field)
    % Compares number of reactions in each subsystem included in the models
    allSubsys = catModelElements(models,field);
    B = zeros(length(allSubsys),numel(models));
    for i=1:numel(models)
        for j=1:length(allSubsys)
            B(j,i) = sum(ismember(models{i}.subSystems,allSubsys(j)));
        end
    end
end

function C = catModelElements(models,field)
    % Creates a vector of all IDs included in models
    A = getElements(models,field);
    allElements = [];
    for i=1:numel(models)
        allElements = [allElements;A{i}];
    end
    C = unique(allElements);
end

function h = genHeatMap(data,colnames,rownames,clust_dim,clust_dist,col_map,col_bounds)
%GENHEATMAP  Generate a heatmap for a given matrix of data.
%
%   GENHEATMAP(DATA,COLNAMES,ROWNAMES,CLUSTER,COL_MAP,COL_BOUNDS) takes as
%   input a matrix of values and produces a heatmap using the built-in
%   PCOLOR function.
%
%--------------------------------- INPUTS ---------------------------------
%
% data        Numerical matrix.
%
% colnames    Names of DATA columns.
% 
% rownames    Names of DATA rows.
%
% clust_dim   'none' - the data will be plotted as provided (DEFAULT)
%             'rows' - cluster/rearrange the rows based on distance
%             'cols' - cluster/rearrange the columns based on distance
%             'both' - cluster/rearrange rows and columns based on distance
%
% clust_dist  Distance metric to be used for clustering, ignored if
%             CLUST_DIM is 'none'. Options are the same as those for
%             distance in, e.g., PDIST ('euclidean', 'hamming', etc.).
%             (DEFAULT = 'euclidean')
%
% col_map     Colormap, provided as string (e.g., 'parula', 'hot', 'etc.')
%             or an Nx3 RGB matrix of N colors.
%             (DEFAULT = 'parula')
%
% col_bounds  A 2-element vector with min and max values, to manually set
%             the bounds of the colormap.
%             (DEFAULT = min/max of DATA).
%
%
% Jonathan Robinson, 2018-03-06
%


% ***** additional adjustable parameters *****
grid_color = 'none';  % color of gridlines (RGB vector or string). e.g., [1 0 0] or 'r' (for red)
linkage_method = 'average';  % linkage algorithm for hierarchical clustering (see linkage function for more options)
% ********************************************


% handle input arguments
if nargin < 7 || isempty(col_bounds)
    col_bounds = [min(data(:)),max(data(:))];
    if nargin < 6 || isempty(col_map)
        col_map = 'parula';
        if nargin < 5 || isempty(clust_dist)
            clust_dist = 'euclidean';
            if nargin < 4 || isempty(clust_dim)
                clust_dim = 'none';
            elseif ~ismember(clust_dim,{'none','rows','cols','both'})
                error('%s is not a valid CLUST_DIM option. Choose "none", "rows", "cols", or "both".',clust_dim);
            end
        end
    end
end


% perform hierarchical clustering to sort rows (if specified)
if ismember(clust_dim,{'rows','both'})
    L = linkage(data,linkage_method,clust_dist);
    row_ind = optimalleaforder(L,pdist(data,clust_dist));
else
    row_ind = 1:size(data,1);
end
% perform hierarchical clustering to sort columns (if specified)
if ismember(clust_dim,{'cols','both'})
    L = linkage(data',linkage_method,clust_dist);
    col_ind = optimalleaforder(L,pdist(data',clust_dist));
else
    col_ind = 1:size(data,2);
end

% reorder data matrix according to clustering results
sortdata = data(row_ind,col_ind);
sortrows = rownames(row_ind);
sortcols = colnames(col_ind);

% check if data is square matrix with identical row and column names
if (length(colnames) == length(rownames)) && all(strcmp(colnames,rownames))
    % flip data so the diagonal is from upper left to lower right
    sortdata = fliplr(sortdata);
    sortcols = flipud(sortcols);
end

% pad data matrix with zeros (pcolor cuts off last row and column)
sortdata(end+1,end+1) = 0;

% generate pcolor plot
warning('off','MATLAB:hg:willberemoved');  % suppress warnings about tick label adjustment not being supported in future Matlab releases.

figure(); % Generate new figure?
a = axes;
set(a,'YAxisLocation','Right','XTick',[],'YTick', (1:size(sortdata,1))+0.5,'YTickLabels',sortrows);
set(a,'TickLength',[0 0],'XLim',[1 size(sortdata,2)],'YLim',[1 size(sortdata,1)]);
hold on

h = pcolor(sortdata);
set(h,'EdgeColor',grid_color);
set(gca,'XTick', (1:size(sortdata,2))+0.5);
set(gca,'YTick', (1:size(sortdata,1))+0.5);
set(gca,'XTickLabels',sortcols,'YTickLabels',sortrows);
set(gca,'XTickLabelRotation',90);
colormap(col_map);

if ~isempty(col_bounds)
    caxis(col_bounds);
end

xl = get(gca,'XLim');
yl = get(gca,'YLim');
plot(xl([1,1,2,2,1]),yl([1,2,2,1,1]),'k');

warning('on','MATLAB:hg:willberemoved');  % turn the warning back on
end

function c = redblue(m)
%REDBLUE    Shades of red and blue color map
%   REDBLUE(M), is an M-by-3 matrix that defines a colormap.
%   The colors begin with bright blue, range through shades of
%   blue to white, and then through shades of red to bright red.
%   REDBLUE, by itself, is the same length as the current figure's
%   colormap. If no figure exists, MATLAB creates one.
%
%   For example, to reset the colormap of the current figure:
%
%             colormap(redblue)
%
%   See also HSV, GRAY, HOT, BONE, COPPER, PINK, FLAG, 
%   COLORMAP, RGBPLOT.

%   Adam Auton, 9th October 2009

if nargin < 1, m = size(get(gcf,'colormap'),1); end

if (mod(m,2) == 0)
    % From [0 0 1] to [1 1 1], then [1 1 1] to [1 0 0];
    m1 = m*0.5;
    r = (0:m1-1)'/max(m1-1,1);
    g = r;
    r = [r; ones(m1,1)];
    g = [g; flipud(g)];
    b = flipud(r);
else
    % From [0 0 1] to [1 1 1] to [1 0 0];
    m1 = floor(m*0.5);
    r = (0:m1-1)'/max(m1,1);
    g = r;
    r = [r; ones(m1+1,1)];
    g = [g; 1; flipud(g)];
    b = flipud(r);
end

c = [r g b];
end