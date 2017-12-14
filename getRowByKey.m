function qkey = getRowByKey(data,key,qAllowMultiple,tol,qCaseInsensitive)
% Multi-index map: query cell-matrix as if map with one or more keys
%
% qkey = getRowByKey(data,key,qAllowMultiple,tol)
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
%   [e{1:4}]  = getRowByKey(data,1)         % this aggragates output back into cell
%                                           % structure, or use:
%   [a,b,c,d] = getRowByKey(data,1)         % for each column as a separate
%                                           % return variable
%   % multiple key:
%   [f{1:3}]  = getRowByKey(data,{1,'t'})
%   [a,b,c]   = getRowByKey(data,{1,'t'})
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
%   [a,b] = getRowByKey(data,1.7)
%   [a,b] = getRowByKey(data,2)             % key 2 not found
%   [a,b] = getRowByKey(data,2,[],.5)       % now tolerance is set to .5,
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
%   [a,b,c,d] = getRowByKey(data,1)         % too many outputs requested
%   [a,b,c] = getRowByKey(data,1)
%   [a,b,c] = getRowByKey(data,'x')         % key combination doesn't exist
%   [a,b,c] = getRowByKey(data,'r')         % key 'r' is multiply defined
%   [a,b,c] = getRowByKey(data,'r',true)    % allow key to be multiply defined
% 
%   % vector as key selects all matching rows
%   [a,b,c] = getRowByKey(data,[1 3])
%   [a,b,c] = getRowByKey(data,{{'r','t'}})         % note below that multiple keys
%                                                   % are defined as a cell array, if
%                                                   % you thus want use a vector of
%                                                   % string values for selecting multiple
%                                                   % items, use a cell array of those
%                                                   % string values inside another cell
%   [a,b,c] = getRowByKey(data,{{'r','t'}},true)    % key 'r' is multiply defined, allow
% 
%   % multiple keys
%   [a,b,c] = getRowByKey(data,{'r',1})     % too many outputs requested
%   [a,b] = getRowByKey(data,{'r',1})       % even though r is multiply defined, 
%                                           % the combination {'r',1} isn't so no error
%   [a,b] = getRowByKey(data,{1,3})         % key doesn't exist
%   [a,b] = getRowByKey(data,{3,4})
% 
%   % multiple keys with one as vector
%   [a,b] = getRowByKey(data,{{'r','t'},1})
%
%   data = { 1 ,2,3,4;...
%            3 ,4,5,6;...
%           'r',1,7,3;...
%           'r',1,5,3;...
%           'r',3,4,5;...
%           't',1,3,5}
%
%   [a,b] = getRowByKey(data,{{'r','t'},1})         % combination of 'r' and 1 is now
%                                                   % multiply defined, error
%   [a,b] = getRowByKey(data,{{'r','t'},1},true)    % allow multiply defined cases
%
% SEE ALSO getRowByKey


% 2010-04-10 DN Split off the below code from getRowByKey
% 2010-12-31 DN Edited comments to reflect this value instead of
%               getRowByKey


% check inputs
if isempty(data)
    qkey  = [];
    return;
end
if iscell(key)
    nKey    = length(key);
else
    nKey    = 1;
    key     = {key};
end
assert(nKey<=size(data,2),'Too many keys given (%d), input has %d columns only',nKey,size(data,2))
if nargin<3 || isempty(qAllowMultiple)
    qAllowMultiple = false;
end
if nargin<4
    tol = eps;
end
if nargin<5
    qCaseInsensitive = false;
end
nMaxRet     = 1;

% match keys
qkey = true(size(data,1),1);
for p=1:nKey
    if isvector(key{p}) && ~isscalar(key{p}) && ~ischar(key{p})
        qtemp = false(size(data,1),1);
        for q=1:length(key{p})
            if iscell(key{p}(q))
                qq = CompareHelper(data(:,p),key{p}{q},tol,qCaseInsensitive);
            else
                qq = CompareHelper(data(:,p),key{p}(q),tol,qCaseInsensitive); 
            end
            qtemp = qtemp | qq;
        end
        qkey = qkey & qtemp;
        nMaxRet = max(nMaxRet,length(key{p}));
    else
        qkey = qkey & CompareHelper(data(:,p),key{p},tol,qCaseInsensitive);
    end
end

% check for multiply-defined
if ~qAllowMultiple
    % this is a very rudimentary check. If one combination does not match
    % at all and the other matches two, this check won't catch it. will
    % need to rethink the matching above.
    % when rethinking anyway, it would be good as well if the code could
    % return indices as well instead of only the boolean (i.e. indices into
    % key's for each row to indicate which key(-combination) matches which
    % row).
    assert(sum(qkey)<=nMaxRet,'key''s multiply defined')
end




function q = CompareHelper(data,key,tol,qCaseInsensitive)

if ischar(key)
    if qCaseInsensitive
        q = cellfun(@(x) strcmpi(x,key),data);
    else
        q = cellfun(@(x) strcmp (x,key),data);
    end
elseif isnumeric(key)
    % make sure we're not comparing to char or other datatypes that are not
    % numeric and thus could never be equal
    q = cellfun(@(x) isnumeric(x) && abs(x-key)<tol,data);
else
    error('datatype %s not supported as key',class(key));
end
