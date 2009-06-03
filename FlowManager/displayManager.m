function displayManager( fieldTrip, sample_data,...
                         metadataUpdateCallback,...
                         rawDataRequestCallback,...
                         autoQCRequestCallback,...
                         manualQCRequestCallback,...
                         exportNetCDFRequestCallback,...
                         exportRawRequestCallback)
%DISPLAYMANGER Manages the display of data.
%
% The display manager handles the interaction between the main window and
% the rest of the toolbox. It defines what is displayed in the main window,
% and how the system reacts when the user interacts with the main window.
%
% Inputs:
%   fieldTrip                   - struct containing field trip information.
%   sample_data                 - Cell array of sample_data structs, one for
%                                 each instrument.
%   metadataUpdateCallback      - Callback function which is called when a 
%                                 data set's metadata is modified.
%   rawDataRequestCallback      - Callback function which is called to 
%                                 retrieve the raw data set.
%   autoQCRequestCallback       - Callback function called when the user 
%                                 attempts to execute an automatic QC routine.
%   manualQCRequestCallback     - Callback function called when the user 
%                                 attempts to execute a manual QC routine.
%   exportNetCDFRequestCallback - Callback function called when the user 
%                                 attempts to export data.
%   exportRawRequestCallback    - Callback function called when the user
%                                 attempts to export raw data.
%
% Author: Paul McCarthy <paul.mccarthy@csiro.au>
%

%
% Copyright (c) 2009, eMarine Information Infrastructure (eMII) and Integrated 
% Marine Observing System (IMOS).
% All rights reserved.
% 
% Redistribution and use in source and binary forms, with or without 
% modification, are permitted provided that the following conditions are met:
% 
%     * Redistributions of source code must retain the above copyright notice, 
%       this list of conditions and the following disclaimer.
%     * Redistributions in binary form must reproduce the above copyright 
%       notice, this list of conditions and the following disclaimer in the 
%       documentation and/or other materials provided with the distribution.
%     * Neither the name of the eMII/IMOS nor the names of its contributors 
%       may be used to endorse or promote products derived from this software 
%       without specific prior written permission.
% 
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
% AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
% ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE 
% LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
% CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
% SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
% INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
% CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
% ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
% POSSIBILITY OF SUCH DAMAGE.
%
  error(nargchk(8,8,nargin));

  if ~isstruct(fieldTrip), error('fieldTrip must be a struct');       end
  if ~iscell(sample_data), error('sample_data must be a cell array'); end
  if isempty(sample_data), error('sample_data is empty');             end

  if ~isa(metadataUpdateCallback, 'function_handle')
    error('metadataUpdateCallback must be a function handle'); 
  end
  if ~isa(rawDataRequestCallback, 'function_handle')
    error('rawDataRequestCallback must be a function handle'); 
  end
  if ~isa(autoQCRequestCallback, 'function_handle')
    error('autoQCRequestCallback must be a function handle'); 
  end
  if ~isa(manualQCRequestCallback, 'function_handle')
    error('manualQCRequestCallback must be a function handle'); 
  end
  if ~isa(exportNetCDFRequestCallback, 'function_handle')
    error('exportNetCDFRequestCallback must be a function handle'); 
  end
  if ~isa(exportRawRequestCallback, 'function_handle')
    error('exportRawRequestCallback must be a function handle'); 
  end
  
  lastState  = '';
  lastSetIdx = [];
  lastVars   = [];
  lastDim    = [];
  
  % define the user options, and create the main window
  states = {'Metadata', 'Raw data', 'Quality Control', ...
            'Export NetCDF', 'Export Raw'};
  mainWindow(fieldTrip, sample_data, states, 2, @stateSelectCallback);
      
  function stateSelectCallback(event,...
    panel, updateCallback, state, sample_data, graphType, setIdx, vars, dim)
  %STATESELECTCALLBACK Called when the user interacts with the main 
  % window, by changing the state, the selected data set, the selected
  % variables/dimension or the selected graph type.
  %
  % Inputs:
  %   event          - String describing what triggered the callback.
  %   panel          - uipanel on which things can be drawn.
  %   updateCallback - function to be called when data is modified.
  %   state          - selected state (string).
  %   sample_data    - Cell array of sample_data structs
  %   graphType      - currently selected graph type (string).
  %   setIdx         - currently selected sample_data struct (index)
  %   vars           - currently selected variables (indices).
  %   dim            - currently selected dimension (index).
  %
  
    switch(state)
      case 'Metadata',        metadataCallback();
      case 'Raw data',        rawDataCallback();
      case 'Quality Control', qcCallback();
      case 'Export NetCDF',   exportNetCDFCallback();
      case 'Export Raw',      exportRawCallback();
    end
    
    lastState  = state;
    lastSetIdx = setIdx;
  
    function metadataCallback()
    %METADATACALLBACK Displays a metadata viewer/editor for the selected 
    % data set.
    %
      % display metadata viewer, allowing user to modify metadata
      viewMetadata(panel, ...
        fieldTrip, sample_data{setIdx}, @metadataUpdateWrapperCallback);

      function metadataUpdateWrapperCallback(sam)
      %METADATAUPDATEWRAPPERCALLBACK Called by the viewMetadata display when
      % metadata is updated. Calls the two subsequent metadata callback
      % functions (mainWindow and flowManager).

        % notify of change to metadata
        metadataUpdateCallback(sam);

        % update GUI with modified data set
        updateCallback(sam);
      end
    end

    function rawDataCallback()
    %RAWDATACALLBACK Displays raw data for the the current data set, using
    %the current graph type.
    %
      % retrieve raw data on state change - if state was already raw data,
      % main window already has the correct data set.
      if strcmp(lastState, state)
        
        sample_data = rawDataRequestCallback();

        % update GUI with raw data set
        for k = 1:length(sample_data), updateCallback(sample_data{k}); end
      end

      % display selected raw data
      graphFunc = str2func(graphType);
      graphFunc(panel, sample_data{setIdx}, vars, dim, false);
    end

    function qcCallback()
    %QCCALLBACK Displays QC'd data for the current data set, using the
    % current graph type. If the state has changed, the autoQCRequestCallback
    % function is called, which may trigger auto-QC routines to be
    % executed.
    %
      % update qc data on state change
      if strcmp(event, 'state')
          
        sample_data = autoQCRequestCallback(setIdx, ~strcmp(lastState,state));

        % update GUI with QC'd data set
        for k = 1:length(sample_data), updateCallback(sample_data{k}); end
      end

      % redisplay the data
      graphFunc = str2func(graphType);
      [graphs lines flags] = ...
        graphFunc(panel, sample_data{setIdx}, vars, dim, true);

      % save line/flag handles and index in axis userdata 
      % so the data select callback can retrieve them
      for k = 1:length(graphs)
        set(graphs(k), 'UserData', {lines(k), flags(k,:), k});
      end

      % add data selection functionality
      selectData(@dataSelectCallback);

      highlight = [];
      function dataSelectCallback(ax, type, range)
      %DATASELECTCALLBACK Called when the user selects a region of data.
      % Highlights the selected region.
      %
        % line/flag handles are stored in the axis userdata
        ud = get(ax, 'UserData');
        
        idx = ud{3};
        
        % get the relevant handle - on a left click, work with 
        % data points; on a right click, work with flags
        handle = 0;
        if     strfind(type, 'normal'), handle = ud{1};
        elseif strfind(type, 'alt'),    handle = ud{2};
        else   return;
        end

        % the graphTimeSeries function sets the flags handle to 0.0 if
        % there were no flags to graph - we must check for this 
        handle = handle(handle ~= 0);
        if isempty(handle), return; end

        % on a drag, update the highlight region
        if strfind(type, 'drag')
          
          % remove any previous highlight
          if ~isempty(highlight)
            delete(highlight); 
            highlight = [];
          end

          % highlight the data, save the handle and data indices
          highlight = highlightData(range, handle); 
          
        % on a click, if on a highlighted region, display 
        % a dialog allowing the user to add/modify flags; 
        % otherwise, clear the highlighted region
        elseif strfind(type, 'click')
          
          if isempty(highlight), return; end
          
          % get the click point, and the highlighted data
          point = get(gca, 'CurrentPoint');
          point = point([1 3]);
          
          highlightX = get(highlight, 'XData');
          highlightY = get(highlight, 'YData');
          
          % figure out if the click was anywhere near the highlight 
          % (within 1% of the current visible range on x and y)
          xError = get(gca, 'XLim');
          xError = abs(xError(1) - xError(2));
          yError = get(gca, 'YLim');
          yError = abs(yError(1) - yError(2));

          % was click near highlight?
          if any(abs(point(1)-highlightX) <= xError*0.01)...
          && any(abs(point(2)-highlightY) <= yError*0.01)

            % popup flag modification dialog
        
          % if the click wasn't near the 
          % highlight, remove the higwhlight
          else
            delete(highlight); 
            highlight = [];
          end
        end
      end
    end
    
    function exportNetCDFCallback()
    %EXPORTNETCDFCALLBACK Called when the user clicks on the 'Export NetCDF' 
    % button. Delegates to the exportNetCDFRequestCallback function.
    %
      exportNetCDFRequestCallback();
      
      stateSelectCallback('', panel, updateCallback, lastState, ...
        sample_data, graphType, setIdx, vars, dim);
      state = lastState;
    end
    
    function exportRawCallback()
    %EXPORTRAWCALLBACK Called when the user clicks on the 'Export Raw'
    % button. Delegates to the exportRawRequestCallback function.
    %
      exportRawRequestCallback();
      
      stateSelectCallback('', panel, updateCallback, lastState, ...
        sample_data, graphType, setIdx, vars, dim);
      state = lastState;
    end
  end
end