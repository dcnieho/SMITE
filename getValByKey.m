function varargout = getValByKey(data,key,qAllowMultiple,tol,qCaseInsensitive)
% Multi-index map: query cell-matrix as if map with one or more keys
% 
% varargout = getValByKey(data,key,qAllowMultiple,tol)
%
% For some cell array in which first x columns are keys and the later
% columns the value(s), gets value(s) by key(s)
% Key(s) can be numeric or string
% Returns (all) empty if key not found or data cell array empty
% If multiple values, each is a seperate output argument. Number of outputs
% must be known, max is size(data,2)-nKeys).
% 
% example:
%   data = {1,'t',4,5,6}
%
%   % single key:
%   [e{1:4}]  = getValByKey(data,1)         % this aggragates output back into cell
%                                           % structure, or use:
%   [a,b,c,d] = getValByKey(data,1)         % for each column as a separate
%                                           % return variable
%   % multiple key:
%   [f{1:3}]  = getValByKey(data,{1,'t'})
%   [a,b,c]   = getValByKey(data,{1,'t'})
%
% An optional third argument (boolean) is allowed: if set to true, keys are
% allowed to be multiply defined, if false (default) an error would be
% generated in that case. Leave empty or don't specify for default (false)
% to be in effect
%
% A fourth optional argument specifies the tolerance to use when matching a
% floating point key, default is eps.
%
% other examples:
%   data = {1.7,'t',4}
%
%   % floating point key
%   [a,b] = getValByKey(data,1.7)
%   [a,b] = getValByKey(data,2)             % key 2 not found
%   [a,b] = getValByKey(data,2,[],.5)       % now tolerance is set to .5,
%                                           % 2 matches 1.7 as
%                                           % abs(2-1.7) = .3 < .5
%
%   data = { 1 ,2,3,4;...
%            3 ,4,5,6;...
%           'r',1,7,3;...
%           'r',3,4,5;...
%           't',1,3,5}
% 
%   % single key
%   [a,b,c,d] = getValByKey(data,1)         % too many outputs requested
%   [a,b,c] = getValByKey(data,1)
%   [a,b,c] = getValByKey(data,'x')         % key combination doesn't exist
%   [a,b,c] = getValByKey(data,'r')         % key 'r' is multiply defined
%   [a,b,c] = getValByKey(data,'r',true)    % allow key to be multiply defined
% 
%   % vector as key selects all matching rows
%   [a,b,c] = getValByKey(data,[1 3])
%   [a,b,c] = getValByKey(data,{{'r','t'}})         % note below that multiple keys
%                                                   % are defined as a cell array, if
%                                                   % you thus want use a vector of
%                                                   % string values for selecting multiple
%                                                   % items, use a cell array of those
%                                                   % string values inside another cell
%   [a,b,c] = getValByKey(data,{{'r','t'}},true)    % key 'r' is multiply defined, allow
% 
%   % multiple keys
%   [a,b,c] = getValByKey(data,{'r',1})     % too many outputs requested
%   [a,b] = getValByKey(data,{'r',1})       % even though r is multiply defined, 
%                                           % the combination {'r',1} isn't so no error
%   [a,b] = getValByKey(data,{1,3})         % key doesn't exist
%   [a,b] = getValByKey(data,{3,4})
% 
%   % multiple keys with one as vector
%   [a,b] = getValByKey(data,{{'r','t'},1})
%
%   data = { 1 ,2,3,4;...
%            3 ,4,5,6;...
%           'r',1,7,3;...
%           'r',1,5,3;...
%           'r',3,4,5;...
%           't',1,3,5}
%
%   [a,b] = getValByKey(data,{{'r','t'},1})         % combination of 'r' and 1 is now
%                                                   % multiply defined, error
%   [a,b] = getValByKey(data,{{'r','t'},1},true)    % allow multiply defined cases


% 2009-11-19 DN wrote it
% 2009-11-20 DN Added support for cell keys and more than one data column
%               Improved error reporting
% 2010-02-02 DN Now supports multiple keys and vector keys, now also
%               optionally supports keys to be mulitply defined
% 2010-02-09 DN Corrected bug with handling multiply defined keys + added
%               serious deocumentation
% 2010-04-10 DN Renamed function, made input order more logical, improved
%               examples, created helper function to cut down on code
%               duplication and added support for matching floating point
%               numbers or using floating point keys with a given tolerance


% check inputs
if isempty(data)
    [varargout{1:nargout}]  = deal([]);
    return;
end
if iscell(key)
    nKey    = length(key);
else
    nKey    = 1;
    key     = {key};
end
assert(nargout<=size(data,2)-nKey,'Too many outputs requested (%d), %d values and %d keys in input',nargout,size(data,2)-nKey,nKey)

if nargin<3 || isempty(qAllowMultiple)
    qAllowMultiple = false;
end
if nargin<4
    tol = eps;
end
if nargin<5
    qCaseInsensitive = false;
end

% do lookup
qkey = getRowByKey(data,key,qAllowMultiple,tol,qCaseInsensitive);


% output
if ~any(qkey) % key not found, return all empty
    [varargout{1:nargout}]  = deal([]);
elseif sum(qkey)==1
    varargout               = data(qkey,nKey+1:end);
else % multiple keys or vector key defined, more elaborate output routine needed
    varargout               = cell(1,nargout);
    for p=1:nargout
        idx = nKey+p;
        if iscellstr(data(:,idx))
            varargout{p} = data(qkey,idx);
        else
            try
                varargout{p} = cat(1,data{qkey,idx});
            catch
                % values cannot be concatenated, output in cell
                varargout{p} = data(qkey,idx);
            end
        end
    end
end
