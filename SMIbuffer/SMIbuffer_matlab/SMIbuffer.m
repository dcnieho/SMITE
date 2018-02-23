% MATLAB class wrapper to underlying C++ class UDPClient

classdef SMIbuffer < handle
    properties (Access = private, Hidden = true)
        objectHandle; % Handle to the underlying C++ class instance
        computerFilter = [];
        debugLevel = 0;
        
        parsedCommandBuffer = {};
        hasSMIIntegration;
    end
    methods
        %% Constructor - Create a new C++ class instance 
        function this = SMIbuffer(varargin)
            this.objectHandle       = UDPClient_matlab('new', varargin{:});
            this.hasSMIIntegration  = UDPClient_matlab('hasSMIIntegration', this.objectHandle);
        end
        
        %% Destructor - Destroy the C++ class instance
        function delete(this)
            UDPClient_matlab('deInit', this.objectHandle);
            UDPClient_matlab('delete', this.objectHandle);
        end

        %% methods
        function init(this)
            UDPClient_matlab('init', this.objectHandle);
        end
        function deInit(this)
            UDPClient_matlab('deInit', this.objectHandle);
        end
        function sendWithTimeStamp(this, varargin)
            % check if first input is numeric, take that as the number of
            % times to send the message
            if isnumeric(varargin{1})
                nSend = varargin{1};
                varargin(1) = [];
            else
                nSend = 1;
            end
            if bitand(this.debugLevel,2)
                fprintf('sent: %s\n',varargin{1});
            end
            % send message
            for p=1:nSend
                UDPClient_matlab('sendWithTimeStamp', this.objectHandle, varargin{:});
            end
        end
        function send(this, varargin)
            UDPClient_matlab('send', this.objectHandle, varargin{:});
        end
        % check if receiver threads are still running. They may close when
        % an exit message is received. function returns how many threads
        % are running
        function numRunning = checkReceiverThreads(this)
            numRunning = UDPClient_matlab('checkReceiverThreads', this.objectHandle);
        end
        
        % get the data and command messages received since the last call to this function
        function data = getData(this)
            data = UDPClient_matlab('getData', this.objectHandle);
        end
        function cmds = getCommands(this)
            cmds = UDPClient_matlab('getCommands', this.objectHandle);
        end
        % get data grouped by computer
        function data = getDataGrouped(this, computers)
            % get default filter if not specified
            if nargin<2
                computers = this.computerFilter;
            end
            % get data messages from C++ buffer
            rawData = this.getData();
            % parse into {ip, timestamps, data}, with possibly multiple
            % rows of timestamps and data per computer
            data = {};
            ips  = [];
            for p=1:length(rawData)
                % optionally, only process messages from specified
                % computers
                if ~isempty(computers) && ~any(rawData(p).ip==computers)
                    continue
                end
                % find where in cell array to put 
                qIp = rawData(p).ip==ips;
                if ~any(qIp)
                    ips(end+1)    = rawData(p).ip;
                    data(end+1,:) = {rawData(p).ip,int64([]),[]};
                    qIp           = rawData(p).ip==ips;
                end
                str    = rawData(p).text;
                commas = find(str==',');
                % moet los, anders krijg je doubles ookal zeg je %*f
                % eerst de timestamps
                str(commas(1):commas(end)-1) = '';
                timestamps = sscanf(str,'%ld,%ld');
                % dat de data
                gazeData   = sscanf(rawData(p).text(commas(1)+1:commas(end)-1),'%f,%f,%f,%f');
                % store
                data{qIp,2}(end+1,:) = [timestamps.' rawData(p).timeStamp];   % SMI timestamp, send timestamp, receive timestamp
                data{qIp,3}(end+1,:) = gazeData;  % leftX, leftY, rightX, rightY
            end
        end
        
        % get cmds, one at a time, filtered and parsed
        function cmd = getSingleCommand(this, computers)
            cmd = [];
            % get default filter if not specified
            if nargin<2
                computers = this.computerFilter;
            end
            % If our buffer is empty, see if any new commands have arrived
            if isempty(this.parsedCommandBuffer)
                this.fillCommandBuffer();
            end
            % see if there is any command to return
            if ~isempty(this.parsedCommandBuffer)
                % loop until we have a command that matches filter
                % things that do not match filter are discarded forever
                while true
                    if isempty(this.parsedCommandBuffer)
                        % nothing left, return empty
                        cmd = [];
                        return;
                    end
                    
                    % pop first-in command and return that
                    cmd = this.parsedCommandBuffer(1,:);
                    this.parsedCommandBuffer(1,:) = [];
                    % see if its a message we want
                    if isempty(computers) || any(cmd{1}==computers)
                        % matches filter, return it
                        return;
                    end
                end
            end
        end
        
        % getters and setters
        function gitRefID = getGitRefID(this)
            gitRefID = UDPClient_matlab('getGitRefID', this.objectHandle);
        end
        function setUseWTP(this, varargin)
            UDPClient_matlab('setUseWTP', this.objectHandle, varargin{:});
        end
        function setMaxClockRes(this, varargin)
            UDPClient_matlab('setMaxClockRes', this.objectHandle, varargin{:});
        end
        function loopback = getLoopBack(this)
            loopback = UDPClient_matlab('getLoopBack', this.objectHandle);
        end
        function setLoopBack(this, varargin)
            UDPClient_matlab('setLoopBack', this.objectHandle, varargin{:});
        end
        function reuseSocket = getReuseSocket(this)
            reuseSocket = UDPClient_matlab('getReuseSocket', this.objectHandle);
        end
        function setReuseSocket(this, varargin)
            UDPClient_matlab('setReuseSocket', this.objectHandle, varargin{:});
        end
        function groupAddress = getGroupAddress(this)
            groupAddress = UDPClient_matlab('getGroupAddress', this.objectHandle);
        end
        function setGroupAddress(this, varargin)
            UDPClient_matlab('setGroupAddress', this.objectHandle, varargin{:});
        end
        function port = getPort(this)
            port = UDPClient_matlab('getPort', this.objectHandle);
        end
        function setPort(this, varargin)
            UDPClient_matlab('setPort', this.objectHandle, varargin{:});
        end
        function bufferSize = getBufferSize(this)
            bufferSize = UDPClient_matlab('getBufferSize', this.objectHandle);
        end
        function setBufferSize(this, varargin)
            UDPClient_matlab('setBufferSize', this.objectHandle, varargin{:});
        end
        function numQueuedReceives = getNumQueuedReceives(this)
            numQueuedReceives = UDPClient_matlab('getNumQueuedReceives', this.objectHandle);
        end
        function setNumQueuedReceives(this, varargin)
            UDPClient_matlab('setNumQueuedReceives', this.objectHandle, varargin{:});
        end
        function numReceiverThreads = getNumReceiverThreads(this)
            numReceiverThreads = UDPClient_matlab('getNumReceiverThreads', this.objectHandle);
        end
        function setNumReceiverThreads(this, varargin)
            UDPClient_matlab('setNumReceiverThreads', this.objectHandle, varargin{:});
        end
        function time = getCurrentTime(this)
            time = UDPClient_matlab('getCurrentTime', this.objectHandle);
        end
        
        % if compiled with SMI integration only
        function startSMIDataSender(this)
            assert(this.hasSMIIntegration,'Can''t startSMIDataSender, UDPClient mex compiled without SMI integration')
            UDPClient_matlab('startSMIDataSender', this.objectHandle);
        end
        function removeSMIDataSender(this)
            assert(this.hasSMIIntegration,'Can''t startSMIDataSender, UDPClient mex compiled without SMI integration')
            UDPClient_matlab('removeSMIDataSender', this.objectHandle);
        end
        
        
        % getters and setters of the matlab class itself
        function this = setComputerFilter(this, filter)
            % set default filter, as well as filter on C side.
            % NB: on the C-side, data acquired before this filter was set
            % is not filtered out and will be returned to the matlab code.
            % this means that if you call data getters that don't filter or
            % if you set an empty filter that allows anything through, you
            % may see a few of these samples. Calling filteredData getters
            % such as getDataGrouped with no input argument will filter out
            % these samples on the matlab side, so there is no issue
            % anymore
            this.computerFilter = filter;
            UDPClient_matlab('setComputerFilter', this.objectHandle, filter);
        end
        function setDebugLevel(this, debugLevel)
            % sets wanted debug output (each bit sets a different
            % functionality, add together to specify which you want):
            % 1: print received commands
            % 2: print sent commands
            % set to 0 to disable completely
            this.debugLevel = debugLevel;
        end
        function clearCommandBuffer(this)
            this.parsedCommandBuffer = {};
            this.getCommands(); % make sure we also clear the C++ buffer by requesting and discarding commands in there
        end
    end
    
    methods (Access = private, Hidden = true)
        function cmds = fillCommandBuffer(this)
            % get cmd messages from C++ buffer
            rawCmd = this.getCommands();
            % parse into {ip, timestamps, message}
            cmds   = cell(length(rawCmd),3);
            for p=1:length(rawCmd)
                if bitand(this.debugLevel,1)
                    fprintf('received from %d: %s\n',rawCmd(p).ip,rawCmd(p).text);
                end
                cmds{p,1} = rawCmd(p).ip;
                % moet los, anders krijg je doubles ookal zeg je %*f
                % eerst de timestamps
                commas= find(rawCmd(p).text==',');
                timestamps = sscanf(rawCmd(p).text(commas(end)+1:end),'%ld');
                % store
                cmds{p,2} = [timestamps rawCmd(p).timeStamp];   % send timestamp, receive timestamp
                cmds{p,3} = rawCmd(p).text(1:commas(end)-1);
            end
            % add parsed commands to buffer
            this.parsedCommandBuffer = [this.parsedCommandBuffer; cmds];
        end
    end
end
