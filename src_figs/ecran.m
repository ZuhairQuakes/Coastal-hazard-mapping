function varargout = ecran(varargin)
% A specialized plot(x,y) function
%
% ecran(handlesMir, x, y [,'title'])
% ecran(handlesMir, x, y, z [,'title'])
% ecran(struct, ...)						% Like the above cases but where 'struct' has only 3 memebers
%											% 'DefineEllipsoide', 'geog' and 'DefineMeasureUnit'
% ecran('reuse', x, y [,'title'])			% Don't know what the 'reuse' is used for anymore
% ecran('add', x, y [,'title'])				% Add the x,y to a previous existing Ecran plot
% ecran('stick', t, angle [,'title'])		% Plot a stick diagram. ANGLE is supposed to be azimuth in degrees
% ecran('stick', t, u, v [,'title'])		% Plot a stick diagram. U,V are vector components. 
% ecran(hMirFig, x, y [,'title'])
% ecran(x, y [,'title'])
% ecran([...,]x, y [,'title'][,PV])			% Where PV is a Mx2N cell array with Property name/values to assign to line handle
%											% N is the number of properties (so 2N means 2 N pairs of PV) and M is > 1 ONLY when
%											% called on more than one line handles (for example the earthtides case)
%											% First PV element may also contain a struct with axes size and a function handle
%											% plus its arguments but this has failed in compiled version for the 'scatter' ex.
%
% x,y can be matrices or vector (x) and matrix (y) where the y columns hold different lines
%
% Function FileOpen_CB() provides several special cases. Namely TIME column input
% and other goodies such reference one line to another. See its help
%
% Also of interest: add_uictx_CB()
% Tricky function either called externally to 'ecran' or activated when loading a file with DATENUM info
% Here is an example on how to use that function from an external call to make x axe plot calendar dates.
%
% 	hf = ecran(SerialDay, TimeSeries);
% 	hAxes = findobj(hf, 'Tag', 'axes1');
% 	setappdata(hAxes, 'LabelFormatType', 'Date');		% Tell pixval_stsbar to display XX coords as Date-Time
% 	h = findobj(hf,'Tag','add_uictx');
% 	cb = get(h, 'Callback');
% 	feval(cb, h, guidata(hf))			% Call the ecran's add_uictx_CB function

% WARNING: WHEN COMPILING NEEDS TO INCLUDE filter_butter.m & legend_.m
%
%	Copyright (c) 2004-2018 by J. Luis
%
% 	This program is part of Mirone and is free software; you can redistribute
% 	it and/or modify it under the terms of the GNU Lesser General Public
% 	License as published by the Free Software Foundation; either
% 	version 2.1 of the License, or any later version.
% 
% 	This program is distributed in the hope that it will be useful,
% 	but WITHOUT ANY WARRANTY; without even the implied warranty of
% 	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
% 	Lesser General Public License for more details.
%
%	Contact info: w3.ualg.pt/~jluis/mirone
% --------------------------------------------------------------------

% $Id: ecran.m 11421 2019-03-18 22:37:04Z j $

	% This before-start test is to allow updating magnetic tracks that are used to pick the isochrons
	% using the convolution method. If no synthetic plot is found, the whole updating issue is simply ignored.
	showBak = get(0,'ShowHiddenHandles');
	set(0,'ShowHiddenHandles','on');
	hObject = findobj(get(0,'Children'),'flat', 'FileName', 'plotxy');
	if (numel(hObject) > 1)			% If there are more than 1, use GCF to distinguish
		hObject = hObject(hObject == gcf);
	end
	set(0,'ShowHiddenHandles',showBak);
	freshFig = true;

	% A test to catch side (nasty) efects of previous run error
	if (~isempty(hObject))
		handles = guidata(hObject(end));
		if (isempty(handles))					% Happens after a previous error run
			delete(hObject),	hObject = [];	% Pretend it never existed and carry on
		end
	end

	if (~isempty(hObject) && ~isempty(varargin))% A previous 'Ecran' figure exists. See if it has a mag synthetic plot
		handles = guidata(hObject(end));
		if (~isempty(handles.hSynthetic) || (~isa(varargin{1},'struct') && strcmp(varargin{1},'add')))
			freshFig = false;
		end
		% Delete eventual existing vertical dashed line and the red square markers
		if (ishandle(handles.hAgeLine_fit))
			delete(handles.hAgeLine_fit),		handles.hAgeLine_fit = [];
		end
		if (ishandle(handles.hLineChunk_fit))
			delete(handles.hLineChunk_fit),		handles.hLineChunk_fit = [];
		end
		hM = findobj(handles.figure1,'Type','Line','tag','marker');
		if (~isempty(hM))
			delete(hM),		set(handles.FileSaveRedMark,'Vis','off')
		end
		if (freshFig),	hObject = [];	end		% So that we force creation of a new fig later down
	elseif (~isempty(hObject) && isempty(varargin) && freshFig)		% A call to "New"
		hObject = [];
	end

	n_in = nargin;		PV = [];	call_fhandle = [];	x_label = '';	y_label = '';
	if (freshFig)								% Almost always true
		if (n_in && isa(varargin{end}, 'cell'))
			if (isa(varargin{end}{1}, 'struct'))
				if (isfield(varargin{end}{1}, 'figSize'))
					hObject = ecran_LayoutFcn(varargin{end}{1}.figSize);
				end
				if (isfield(varargin{end}{1}, 'xlabel')),	x_label = varargin{end}{1}.xlabel;	end
				if (isfield(varargin{end}{1}, 'ylabel')),	y_label = varargin{end}{1}.ylabel;	end
				if (isfield(varargin{end}{1}, 'fhandle'))
					% Here the fhandles must be a cell with 2 elements. First containing the function name
					% to be run and the second element another cell array with its arguments.
					call_fhandle = varargin{end}{1}.fhandle;	% The function name
				end
				varargin{end}(1) = [];
				if (isempty(varargin{end}))		% It might not be empty if PV line props are present
					varargin(end) = [];		n_in = n_in - 1;
				end
			end
		end

		if (isempty(hObject))					% Still need to create the Fig
			hObject = ecran_LayoutFcn;
		end
		handles = guihandles(hObject);
		if (~isempty(x_label)),		set(get(handles.axes1, 'XLabel'), 'Str',x_label),	end
		if (~isempty(y_label)),		set(get(handles.axes1, 'YLabel'), 'Str',y_label),	end
		move2side(hObject,'right');

		handles.Misc_menu = findobj(handles.figure1, 'Label','Misc');

		mir_dirs = getappdata(0,'MIRONE_DIRS');
		if (~isempty(mir_dirs))
			handles.home_dir = mir_dirs.home_dir;		% Start in values
			handles.work_dir = mir_dirs.work_dir;
			handles.last_dir = mir_dirs.last_dir;
			handles.path_data = mir_dirs.path_data;
			handles.path_tmp  = mir_dirs.path_tmp;
			handles.version7  = mir_dirs.version7;
			handles.IamCompiled = mir_dirs.IamCompiled;
		else
			handles.home_dir = cd;		handles.work_dir = cd;		handles.last_dir = cd;
		end
		handles.hMirFig = [];

		handles.d_path = [handles.home_dir filesep 'data' filesep];
		s = load([handles.d_path 'mirone_pref.mat'],'directory_list');
		try			handles.last_dir = s.directory_list{1}; 	end
	elseif (isempty(hObject))
		errordlg('ECRAN: Requested ADD to a previous plot but the Figure does not exists.','Error')
		return
	end

	% ---- OK, the interface for this function is a mess. In part due to backward compatibility issues
	if (~n_in),   varargin(1) = {[]};   end
	if (isa(varargin{end}, 'cell'))					% A cell with Property-Values for lines (no testing correctness)
		PV = varargin{end};		varargin(end) = [];		n_in = n_in - 1;
	end

	handles.handMir = [];		handles.show_popups = true;
	handles.ellipsoide = [];	handles.geog = [];
	handles.measureUnit = [];	handles.IamXY = true;
	if (isa(varargin{1},'struct'))					% ecran(handlesMir, ...) or ecran(struct, ...)
		if (isfield(varargin{1},'LoadBGMap'))		% First arg is the Mirone handles struct
			handles.handMir   = varargin{1};
			handles.work_dir  = handles.handMir.work_dir;
			handles.path_data = handles.handMir.path_data;
			handles.path_tmp  = handles.handMir.path_tmp;
			handles.version7  = handles.handMir.version7;
			handles.IamCompiled = handles.handMir.IamCompiled;
		end
		handles.ellipsoide = varargin{1}.DefineEllipsoide;
		handles.geog = varargin{1}.geog;
		handles.measureUnit = varargin{1}.DefineMeasureUnit;
		varargin{1} = 'Image';						% For backward compatibility sake
		if (n_in == 3)								% ecran(handlesMir, x, y)
			varargin{1} = 'reuse';
		elseif (n_in == 4 && ischar(varargin{4}) )	% ecran(handlesMir, x, y, 'title')
			varargin{1} = 'reuse';		varargin{5} = varargin{4};		% Figure title
			varargin{4} = [];			n_in = 5;						% Pretend we had one more argin
		end
	elseif (~isempty(varargin{1}))					% ecran(..., x, y, ...)
		if (ischar(varargin{1}) && strcmp(varargin{1},'stick'))
			% Decrease n_in so that last arg may be used for Fig name and at same time tell between the 2 use modes
			if (isa(varargin{end}, 'char')),	n_in = n_in - 1;	end
		elseif (n_in >= 3 && ischar(varargin{1}))	% ecran('reuse', x, y, ...)
			varargin{1} = 'reuse';			% Make sure we use this keyword

		elseif (n_in >= 3 && numel(varargin{1}) == 1 && ishandle(varargin{1}))	% ecran(hMirFig, x, y, ...)
			handles.hMirFig = varargin{1};
			varargin{1} = 'reuse';			% 

		elseif ((n_in >= 2) && isnumeric(varargin{1}) && isnumeric(varargin{2})) % ecran(x, y, ...)
			if (n_in == 2)					% All args are numeric
				varargin(2:3) = varargin(1:2);
				n_in = 3;
			else							% Two numeric and a title
				varargin(2:4) = varargin(1:3);
				if (ischar(varargin{4}))	% Fig name
					varargin{5} = varargin{4};
					n_in = 5;
				end
			end
			varargin{1} = 'reuse';			% STUPID IDEA, now I can't use it to REALY mean a reuse
		end
	end

	if (strcmp(varargin{1},'reuse') && n_in < 3)
		errordlg('Error calling ecran: Minimum arguments are "type",X,Y,Title','Error')
		delete(hObject),		return
	end
	if (strcmp(varargin{1},'Image') && n_in < 5)   
		errordlg('Error calling ecran: Minimum arguments are "type",X,Y,Z,Title','Error')
		delete(hObject),		return
	end

	if (freshFig)
		% ------------------ Set the UITOOLBAR and its buttons -------------------------------------
		s = load([handles.d_path 'mirone_icons.mat'],'zoom_ico','zoomx_ico', 'clipcopy_ico',...
			'Mline_ico', 'rectang_ico', 'bar_ico', 'text_ico', 'legend');
		link_ico = make_link_ico;

		hTB = uitoolbar('parent',hObject,'Clipping', 'on', 'BusyAction','queue','HandleVisibility','on',...
		               'Interruptible','on','Tag','FigureToolBar','Visible','on');
		uitoggletool('parent',hTB,'Click',{@zoom_CB,''}, 'cdata',s.zoom_ico,'Tooltip','Zoom', 'Tag','ZoomToggle');
		uitoggletool('parent',hTB,'Click',{@zoom_CB,'x'},'cdata',s.zoomx_ico,'Tooltip','Zoom X', 'Tag','Zoom_xToggle');
		if (strncmp(computer,'PC',2))
			uipushtool('parent',hTB,'Click',@copyclipbd_CB, 'cdata',s.clipcopy_ico,'Tooltip','Copy to clipboard ','Sep','on');
		end
		if (~isempty(handles.handMir))
			uitoggletool('parent',hTB,'Click',@pick_CB, 'cdata',link_ico,'Tooltip', ...
			             'Pick data point in curve and plot it on the Mirone figure','Sep','on', 'Tag', 'pick_but');
		end
		uitoggletool('parent',hTB,'Click',@dynSlope_CB, 'cdata', s.Mline_ico,...
		             'Tooltip','Compute slope dynamically', 'Tag', 'DynSlope');
		uipushtool('parent',hTB,'Click',@rectang_clicked_CB,'cdata',s.rectang_ico,...
		           'Tooltip','Restrict analysis to X region', 'Tag', 'rectang_but');
		uipushtool('parent',hTB,'Click',@write_text_CB, 'cdata',s.text_ico,'Tooltip','Write text','Sep','on');
		uitoggletool('parent',hTB,'Click',@isocs_CB, 'cdata', s.bar_ico,...
		             'Tooltip','Enter ages & plot a geomagnetic barcode','Sep','on', 'Tag', 'isocs_but');
		uitoggletool('parent',hTB,'Click',@legend_CB, 'cdata', s.legend,...
		             'Tooltip','Insert a Legend','Sep','on', 'Tag', 'Legend');
		% -------------------------------------------------------------------------------------------

		handles.hLine = [];			% Handles to the ploted line
		handles.syntPar = [];		% To hold synthetic mag profile creation parameters
		handles.hSynthetic = [];	% To hold the mag synthetic profile
		handles.n_plot = 0;         % Counter of the number of lines. Used for line color painting
		handles.dist = [];			% It will contain cumulated distance if input is (x,y,z)
		handles.polyFig = [];		% Handles to the (eventual) figure for trend1d polyfit
		handles.hRect = [];			% Handles to a XLim analysis limiting rectangle
		handles.ageStart = 0;		handles.ageEnd = nan;
		handles.hAgeMarker = [];	% Isochron anchor point
		handles.hAgeLine_fit = [];	% Float chunk line used to CORR fit to find ideal isochron pick
		handles.hLineChunk_fit = [];% Anchor point, now a vert line, moved to new fit pos
		handles.batTrack = [];		% To hold the bat interpolated profile
		handles.pinned = [];		% To hold coords of guessed magnetic isochrons
		handles.hPatchMagBar = [];	% Handles of the Mag Bars
		handles.hTxtChrons = [];	% Handles of isochrons names (when used)
		handles.no_file = false;	% Will need to be updated latter to true case (used in write_gmt_script)
		handles.hMarkerToRef = [];	% To hold the handles of an eventual markers 'to reference type line'
		handles.offset_coords = [0 0];	% Will store new origin after a Shift origin op
		handles.offset_axes   = '';	% Save info on which axe(s) a coordinate shift was applyied
		handles.fname_session = '';	% If a session is loaded, save its full file name in here
		handles.hLegend = [];		% To hold the axes legend handle
		handles.converted2dates = false;	% To assure that time conversions are done only once.
	end

	% Choose the default ploting mode
	if isempty(varargin{1})			% When the file will be read latter
		set([handles.check_geog handles.popup_selectPlot handles.popup_selectSave], 'Visible','off')	% Hide those
		handles.show_popups = false;

		% See if we have some function handle to execute (e.g. 'scatter' like the ARGO plots)
		if (~isempty(call_fhandle))
			fh = str2func(call_fhandle{1});		% This failed with scatter. The reason is obscure.
			o = feval(fh,call_fhandle{2}{:});
			handles.hLine = o;
		end

	elseif strcmp(varargin{1},'Image')			% Case when it comes referenced to a grid/image
		if (size(varargin{2},2) == 1)			% When they are column vectors Z can contain several columns
			handles.data = [varargin{2} varargin{3} varargin{4}];
		else
			handles.data = [varargin{2}(:) varargin{3}(:) varargin{4}(:)];
		end
		set(handles.popup_selectSave,'String',{'Save Line on disk';'Distance,Z (data units, text)';
			'Distance,Z (data units, binary)';'X,Y,Z (data units, text)';'X,Y,Z (data units, binary)'});
		rd = get_distances(handles.data(:,1), handles.data(:,2), handles.geog, handles.measureUnit, handles.ellipsoide);
		handles.dist = rd;			% This one is by default, so save it in case user wants to save to file

		if (freshFig)				% First time here. Create the line handle
			handles.hLine = line('XData',rd,'YData',handles.data(:,3), 'Parent', handles.axes1, 'Color','b');
			if (size(handles.data, 2) > 3)		% We have more lines to plot
				for (k = 4:size(handles.data, 2))
					handles.hLine(k-2) = line('XData',rd,'YData',handles.data(:,k), 'Parent', handles.axes1, 'Color', rand(1,3));
				end
			end
			y_lim = [min(min(handles.data(:,3:end))) max(max(handles.data(:,3:end)))];
			if (diff(y_lim) < 1e-8),		y_lim = y_lim + [-1 1];		end		% To not error below
			set(handles.axes1,'xlim',[rd(1) rd(end)], 'ylim',y_lim)
		else
			% Update the track line, but need to reposition also the isochrons texts (names) AND update sythetic
			set(handles.hLine,'XData',rd, 'YData',handles.data(:,3))
			set(handles.axes1,'xlim',[rd(1) rd(end)], 'ylim',[min(handles.data(:,3)) max(handles.data(:,3))])
			push_magBar_CB(handles.push_magBar, handles)
			handles = guidata(handles.figure1);		% Get the updated version (changed in the previous call)
			handles.batTrack = [];					% Force recomputing (if used, ofc)
			push_syntheticRTP_CB(handles.push_syntheticRTP, handles)
			handles = guidata(handles.figure1);
			popup_ageFit_CB(handles.popup_ageFit, handles)
		end

		if (handles.geog)				% Update uicontrol values too
			set(handles.check_geog,'Val',1)
			check_geog_CB(handles.check_geog, handles)
			if (handles.measureUnit == 'k'),		set(handles.popup_selectPlot,'Val',2)
			elseif (handles.measureUnit == 'n'),	set(handles.popup_selectPlot,'Val',3)
			elseif (handles.measureUnit == 'm'),	set(handles.popup_selectPlot,'Val',4)
			end
		end
		set(hObject,'Name',varargin{5})

	elseif strcmp(varargin{1},'reuse')					% Case of (x, y) or auto-referenced call
		varargin(n_in+1:9) = cell(1,9-n_in);			% So that varargin{1:9} allways exists.
		set([handles.check_geog handles.popup_selectPlot handles.popup_selectSave], 'Visible','off')	% Hide those
		handles.data = parse_numeric_input(varargin{2}, varargin{3}, []);
		for (k = 1:size(handles.data,3))		% Loop over the number of lines
			if (~isempty(varargin{9}) && strcmp(varargin{9},'semilogy'))
				set(handles.axes1, 'YScale', 'log')
				handles.hLine(k) = semilogy(handles.data(:,1,k),handles.data(:,2,k), 'Parent', handles.axes1);
			elseif (~isempty(varargin{9}) && strcmp(varargin{9},'semilogx'))
				set(handles.axes1, 'XScale', 'log')
				handles.hLine(k) = semilogx(handles.data(:,1,k),handles.data(:,2,k), 'Parent', handles.axes1);
			else
				handles.hLine(k) = plot(handles.data(:,1,k),handles.data(:,2,k), 'Parent', handles.axes1);
				if (~freshFig || k > 1)
					set(handles.hLine(k),'Color',rand(1,3))	% We want a different color but NextPlot prop was set to 'add'
				end
			end
		end
		axis(handles.axes1,'tight');

		if (~isempty(varargin{5})),    set(hObject,'Name',varargin{5});		end		% Figure Name
		if (~isempty(varargin{6})),    xlabel(varargin{6});					end		% XLabel
		if (~isempty(varargin{7})),    ylabel(varargin{7});					end		% YLabel
		if (~isempty(varargin{8}))			% Cannot cal title(varargin{8}) in compiled version because ... BUGS;
			ax = handles.axes1;		h = get(ax,'title');
			%Over-ride text objects default font attributes with the Axes' default font attributes.
			set(h, 'FontAngle',  get(ax, 'FontAngle'), 'FontName', get(ax, 'FontName'), 'FontSize', get(ax, 'FontSize'), ...
			       'FontWeight', get(ax, 'FontWeight'),'Rotation',   0, 'string', varargin{8});
		end
		handles.show_popups = false;

	elseif strcmp(varargin{1},'stick')
		if (n_in == 3)		% Angles only. Assume it's azimuth in degrees
			[X, Y] = pol2cart(mod(varargin{3}(:) -90, 360)*pi/180, 1);
			handles.data = [varargin{2}(:) X Y];
		elseif (n_in == 4)
			handles.data = [varargin{2}(:) varargin{3}(:) varargin{4}(:)];
		end
  		handles.hLine = sticks(handles.axes1, handles.data(:,1), handles.data(:,2), handles.data(:,3));
		if (isa(varargin{end}, 'char')),	set(hObject,'Name',varargin{end}),	end

	end

	% This is a new feature, for now only for time conversions to allow display calendar labels
	if (strcmp(get(handles.check_geog, 'Vis'), 'on'))		% If geog then for sure no time conversions are possible
		set(handles.Misc_menu, 'Vis', 'off')
	end

	handles.cmenu_axes = uicontextmenu('Parent',handles.figure1);	% Save it because we need it in "add_uictx_CB()"
	set(handles.axes1, 'UIContextMenu', handles.cmenu_axes);
  	set(handles.axes1, 'ButtonDownFcn', {@hide_uimenu,handles.figure1});
	handles.uimenuGrid = uimenu(handles.cmenu_axes, 'Label', 'Grid on/off', 'Callback', 'grid');

	is_CMOP = false;
	if (~isempty(PV))
		for (k = 1:size(PV,1))
			for (m = 1:2:size(PV,2))
				if (PV{k,m}(1) ~= '_')		% If property name starts with a '_' means it's to be set by appdata
					set(handles.hLine(k), PV{k,m},PV{k,m+1})
				else
					setappdata(handles.hLine(k), PV{k,m}(2:end),PV{k,m+1})
				end
			end
		end
		if (strcmp(get(handles.hLine, 'tag'), 'CMOP'))
			cmenuHand = uicontextmenu('Parent',handles.figure1);
			set(handles.hLine, 'UIContextMenu', cmenuHand);
			uimenu(cmenuHand, 'Label', 'Make scatter plot with Me and the other CMOP line Me', 'Callback', @make_scatterPlot);
			uimenu(cmenuHand, 'Label', 'Filter Outliers', 'Callback', {@outliers_clean,handles.hLine}, 'Sep','on');
			is_CMOP = true;
		end
	end

	if (~isempty(handles.hLine)),	handles.n_plot = 1;		end		% Always true in cases where varargin{1} ~= []

	% These are not needed here but must exist in pixval_stsbar() and have the same meaning as in the mirone figs
	handles.image_type = 20;
	handles.is_projected = false;
	handles.DefineMeasureUnit = 'user';		% Always use 'user' units even if we know 'geog'. The point is Y is never geog

	handles.is_defRegion = false;
	handles.fileName = '';
	handles.Illumin_type = 0;
	handles.validGrid = false;
	setappdata(handles.axes1,'ThisImageLims', [get(handles.axes1,'XLim') get(handles.axes1,'YLim')])

	if (~isempty(handles.ellipsoide))
		handles.DefineEllipsoide = handles.ellipsoide;
	else
		handles.DefineEllipsoide = [6378137, 0, 1/298.2572235630];	% WGS84, but this is only used if 'geog' anyway.
	end
	% --------------------------------------------------------------------------------------------------------

	if (freshFig),	handles = createframe(handles);		end
	guidata(hObject, handles);
	set(hObject,'Vis','on');
	if (~is_CMOP && ~isempty(handles.hLine))
		draw_funs([], 'set_line_uicontext_XY', handles.hLine, 'main')		% Set lines's uicontextmenu
		finish_line_uictx(handles.hLine)		% Assign the callbacks to menus only declared by draw_funs()
	end
	if (nargout),	varargout{1} = hObject;		end

%--------------------------------------------------------------------------
function data = parse_numeric_input(X, Y, Z)
% X,Y,Z can be:
%	All vectors
%	All 2D matrices with the same sizes
%	X a vector and Y/Z 2D matrices with the same size and number of rows equal to numel(X)
% On top of this, Z can be empty (the case of a simple x,y input)
%
% The output is a 2D matrix (first case) or a 3D matrix where each layer contains one curve.

	if (any(size(X) == 1) && any(size(Y) == 1))		% Simple single line case but where Z is not tested
		data = [X(:) Y(:) Z(:)];
		return
	end

	if (isequal(size(X), size(Y)))		% X & Y are matrix with the same dimensions, again Z is not tested
		if (isempty(Z))
			data = zeros(size(X,1), 2, size(Y,2));
			for (k = 1:size(Y,2))
				data(:,:,k) = [X(:,k) Y(:,k)];
			end
		else
			data = zeros(numel(X), 3, size(Y,2));
			for (k = 1:size(Y,2))
				data(:,:,k) = [X(:,k) Y(:,k) Z(:,k)];
			end
		end
	elseif (any(size(X) == 1) && all(size(Y) ~= 1))		% X is a vector Y is a matrix
		if (numel(X) ~= size(Y,1))
			error('ECRAN:Number of X elements must be equal to number of Y rows')
		end
		if (isempty(Z))
			data = zeros(numel(X), 2, size(Y,2));
			for (k = 1:size(Y,2))
				data(:,:,k) = [X(:) Y(:,k)];
			end
		else
			if (~isequal(size(Y), size(Z)))
				error('ECRAN: size of matrices Y and Z must be equal')
			end
			data = zeros(numel(X), 3, size(Y,2));
			for (k = 1:size(Y,2))
				data(:,:,k) = [X(:) Y(:,k) Z(:,k)];
			end
		end
	end

%--------------------------------------------------------------------------
function handles = createframe(handles)
% Creates a virtual panel to display the coordinates and measures

	H = 20;		% The status bar height
	figPos = get(handles.figure1, 'Pos');		axPos = get(handles.axes1, 'Pos');
	hAx = handles.axes2;
	x1 = 0;     x2 = figPos(3);
	y1 = axPos(2)+axPos(4)-1;		y2 = y1 + H;

	% I could (should?) do it simpler since these line are only used in pixval_stsbar to determine
	% where to plot the coords status bar. But I must maintain compatibility with resizetrue()
	hFrame(1) = line([x1 x2],[y2 y2],'Visible','off','Tag','Sts_T','parent',hAx);    % Top line
	hFrame(2) = line([x1 x1],[y1 y2],'Visible','off','Tag','Sts_L','parent',hAx);    % Left line

	setappdata(handles.figure1,'CoordsStBar',[hAx hFrame]);		% Save it for use in pixval_stsbar

	X = get(handles.axes1, 'XLim');		Y = get(handles.axes1, 'YLim');
	handles.head = [X Y 0 255 0 0 0];
	nx = axPos(3);		ny = axPos(4);
	handles.head(8) = diff(X) / (nx - 1);	handles.head(9) = diff(Y) / (ny - 1);

	geog = handles.geog;
	handles.geog = 0;			% Have to set it to not because handles.geog has a very different usage in pixval_stsbar()
	guidata(handles.figure1, handles);		% This has to go first because pixval_stsbar is expecting un updated version
	pixval_stsbar(handles.figure1)
	handles.geog = geog;		% And now restore original value

% -----------------------------------------------------------------------------
function ico = make_link_ico()
% construct the link icon (not yet in mirone_icons.mat)
	ico	= uint8([	226  239  238  238  238  238  238  238  238  238  238  238  238  238  240  221; ...
					240  254  253  253  253  253  253  253  253  255  255  255  253  253  254  236; ...
					236  251  250  250  250  250  250  250  253  244  156  183  255  250  251  233; ...
					235  247  247  247  247  247  247  250  245  132  145  124  167  254  248  232; ...
					234  244  244  244  244  244  245  240  127  147  250  224  119  176  251  231; ...
					232  240  239  239  239  239  248  148  145  189  243  255  141  144  248  230; ...
					232  238  238  238  239  244  247  198  151  107  189  149  113  223  241  228; ...
					229  232  232  233  236  137  187  154  107  139  137  107  217  236  232  227; ...
					225  221  223  228  110  124  139  100  131  188  129  207  226  221  221  223; ...
					226  223  227  106  114  199   84  129  174  233  231  224  222  222  222  224; ...
					227  233  135  105  230  238  201  116  121  233  225  225  225  225  225  225; ...
					228  233  154   81  206  244  116   88  219  227  225  225  225  225  225  226; ...
					227  227  246  126   77  103   85  223  231  228  228  228  228  228  228  225; ...
					228  230  229  247  149  119  221  233  230  230  230  230  230  230  230  226; ...
					230  232  232  232  239  241  234  232  232  232  232  232  232  232  232  228; ...
					218  229  228  228  228  228  228  228  228  228  228  228  228  228  229  216]);
	  ico = repmat(ico,[1 1 3]);

% --------------------------------------------------------------------------------------------------
function hide_uimenu(obj,evt, hFig)
% This function serves only to not show the annoying uicontextmenu when we right-click on the plotting area.
% I don't know what happens in this program, but this was the only way I found to do it, and I tried.
% The problem will be we need the 'ButtonDownFcn' for something else
	st = get(hFig,'SelectionType');
	if (strcmp(st, 'alt'))
		handles = guidata(hFig);
		pt = get(handles.axes1, 'CurrentPoint');
		x_lim = get(handles.axes1,'XLim');		y_lim = get(handles.axes1,'YLim');
		if ((pt(1) > x_lim(1) && pt(1) < x_lim(2)) && (pt(1,2) > y_lim(1) && pt(1,2) < y_lim(2)))
			set(handles.uimenuGrid,'Vis','off')
		else
			set(handles.uimenuGrid,'Vis','on')
		end
	end

% --------------------------------------------------------------------------------------------------
function finish_line_uictx(hLine)
% draw_funs/set_line_uicontext_XY() declared these menus but did not assign Callbacks to them. Do it now
	for (k = 1:numel(hLine))
		uictx = get(hLine(k), 'UIContextMenu');
		h = findobj(uictx, 'Label', 'X origin only');
		set(h, 'Callback', {@shift_orig, 'X'})
		h = findobj(uictx, 'Label', 'Y origin only');
		set(h, 'Callback', {@shift_orig, 'Y'})
		h = findobj(uictx, 'Label', 'XY origin');
		set(h, 'Callback', {@shift_orig, 'XY'})
		h = findobj(uictx, 'Label', 'Filter Outliers');
		set(h, 'Callback', {@outliers_clean, hLine(k)})
		h = findobj(uictx, 'Label', 'Filter line');
		set(h, 'Callback', {@AnalysisFilter_CB, hLine(k)})
		h = findobj(uictx, 'Label', 'Show histogram');
		set(h, 'Callback', {@do_histogram, hLine(k), 'Hist'})
		h = findobj(uictx, 'Label', 'Show Bar graph');
		set(h, 'Callback', {@do_histogram, hLine(k), 'Bar'})
	end

% --------------------------------------------------------------------------------------------------
function shift_orig(obj, evt, eixo, hLine, pt_x, pt_y, opt)
% Shift the graph origin to either a new X0, Y0 or both. The new origin is the closest point on curve to the clicking pt
% HLINE, PT_X, PT_Y & OPT are optional arguments that are transmitted when this function is called from OpenSession
	if (nargin < 4),		hLine = gco;	end
	handles = guidata(get(get(hLine, 'Parent'), 'Parent'));
	if (nargin < 5)
		[pt_x, pt_y] = get_pointOnLine(handles.axes1, hLine);	% Get the clicked closest point on line
	end
	if (nargin < 7),	opt = '';	end

	if (strcmpi(eixo, 'X')),		pt_y = 0;
	elseif (strcmpi(eixo, 'Y')),	pt_x = 0;
	end

	hZ1 = findobj(handles.figure1, 'Tag','ZoomToggle');
	hZ2 = findobj(handles.figure1, 'Tag','Zoom_xToggle');
	zoom_is_on = false;
	if (strcmp(get(hZ1,'State'),'on') || strcmp(get(hZ2,'State'),'on'))
		zoom_is_on = true;
	end
	if (strcmp(eixo, 'X'))
		x = get(hLine, 'XData');		x = x - pt_x;
		set(hLine, 'XData', x)
		shift_children(handles, hLine, pt_x, pt_y, eixo, opt)		% Shift other eventual Text and Line elements
		if (zoom_is_on),	zoom_j('out'),	zoom_j('off'),	end		% Must always turn Zoom off otherwise it screws when manually zooming out
		set(handles.axes1, 'XLim', [x(1) x(end)])
		handles.dist = x;
	elseif (strcmp(eixo, 'Y'))
		y = get(hLine, 'YData');		y = y - pt_y;
		set(hLine, 'YData', y)
		shift_children(handles, hLine, pt_x, pt_y, eixo, opt)		% Shift other eventual Text and Line elements
		if (zoom_is_on),	zoom_j('out'),	zoom_j('off'),	end
		set(handles.axes1, 'YLim', [min(y) max(y)])
	else			% Both X & Y
		x = get(hLine, 'XData');		x = x - pt_x;
		y = get(hLine, 'YData');		y = y - pt_y;
		set(hLine, 'XData', x, 'YData', y)
		shift_children(handles, hLine, pt_x, pt_y, eixo, opt)		% Shift other eventual Text and Line elements
		if (zoom_is_on),	zoom_j('out'),	zoom_j('off'),	end
		set(handles.axes1, 'XLim', [x(1) x(end)], 'YLim', [min(y) max(y)])
		handles.dist = x;
	end
	handles.offset_coords = handles.offset_coords + [pt_x pt_y];	% Save for eventual use in Sessions and accumulate from any previous
	if (~isequal(handles.offset_axes, eixo))
		handles.offset_axes = char(unique(double([handles.offset_axes eixo])));	% Make sure we have only a 'X' or 'Y' or 'XY'
	end
	guidata(handles.figure1, handles)

% --------------------------------------------------------------------------------------------------
function shift_children(handles, hLine, pt_x, pt_y, eixo, opt)
% Shift all Text and line objects, except HLINE that was already shifted
% But since this function is also called upon a Session load we must protect against multiple shifting
	if (~isempty(opt))
		% OK, here is what happening. There was a shift stored in the .mat file but that shift
		% has already been applied to the targets of this function (by a previous run of this code)
		% so we don't want to applyit again and hence return right away.
		return
	end

	% Fish Texts and shift them
	ALLtextHand = findobj(get(handles.axes1,'Child'),'Type','text');
	for (k = 1:numel(ALLtextHand))
		pos = get(ALLtextHand(k), 'Pos');
		pos(1,1) = pos(1,1) - pt_x;		pos(1,2) = pos(1,2) - pt_y;
		set(ALLtextHand(k), 'Pos', pos);
	end

	% Fish Lines and shift them
	ALLlineHand = findobj(get(handles.axes1,'Child'),'Type','line');
	ALLlineHand = setxor(ALLlineHand, hLine);		% The HLINE line has already been shifted, so remove it from list
	for (k = 1:numel(ALLlineHand))
		x = get(ALLlineHand(k), 'XData');	y = get(ALLlineHand(k), 'YData');
		if (pt_x ~= 0),		set(ALLlineHand(k), 'XData', x - pt_x),		end
		if (pt_y ~= 0),		set(ALLlineHand(k), 'YData', y - pt_y),		end
	end

% --------------------------------------------------------------------------------------------------
function zoom_CB(obj,evt,opt)
	if (strcmp(get(obj,'State'),'on'))
		if (strcmp(opt,'x')),		zoom_j xon;
		else,						zoom_j on;
		end
	else
		zoom_j off;
	end

% --------------------------------------------------------------------------------------------------
function copyclipbd_CB(obj,eventdata)
% Copy curve(s) to the Windows clipboard.
	handles = guidata(obj);
	if (isempty(handles.hLine)),	return,		end
	hLines = findobj(handles.axes1,'type','line');
	x = get(hLines(1), 'xdata');	y = get(hLines, 'ydata');
	if (~isa(y,'cell'))
		data = [x(:) y(:)];
	else
		n_pts = numel(x);
		nys = zeros(numel(y),1);
		for (k = 1:numel(y)),		nys(k) = numel(y{k});	end		% Count each curve number of points
		ind = find(nys == nys(1));			% See if they are all of the same size
		if (numel(ind) == numel(nys))		% All curves have the same number of points. Good.
			data = x(:);
			for (k = 1:numel(y))			% Loop over number of curves
				data = [data y{k}(:)];		% Slower due to non-preallocation but safe
			end
		else
			% Search for the first curve that has as many points as the X vector 
			for (k = 1:numel(y))			% Loop over number of curves
				if (numel(y{k}) == n_pts)
					data = [x(:) y{k}(:)];	% Found one (We must have at least one)
					break
				end
			end
			warndlg('Several curves but not all of the same size. Only one was copyied.','Warning')
		end
	end
	mat2clip(data)

% ------------------------------------------------------------------------------------------
function dynSlope_CB(obj, eventdata)
% Compute slope over the click and drag region.

	handles = guidata(obj);				mkAnother = false;
	if (~strcmp(get(obj,'State'),'on'))				% Unchecked, so hide the dynslope objects
		set(handles.axes2, 'Vis', 'off')
		set(findobj(handles.axes2,'Type', 'line', 'Tag', 'UnderLine'), 'Vis', 'off')
		set(findobj(handles.axes1,'Type', 'line', 'Tag', 'FitLine'), 'Vis', 'off')
		set(findobj(handles.axes2,'Type', 'text', 'Tag', 'DS'), 'Vis', 'off')
		set(handles.figure1,'Pointer', 'arrow');	% Could be cross when unsetting the toggle button
		displayBar = findobj(handles.figure1, 'Tag', 'pixValStsBar');
		if (isempty(displayBar))					% pixValStsBar was deleted but not yet recreated. Time to reborn it
			pixval_stsbar(handles.figure1)
		else
			set(displayBar, 'Vis','on')
		end
		return
	else
		hULine = findobj(handles.axes2,'Type', 'line', 'Tag', 'UnderLine');
		hFLine = findobj(handles.axes1,'Type', 'line', 'Tag', 'FitLine');
		hTxt = findobj(handles.axes2,'Type', 'text', 'Tag','DS');
		if (~isempty(hULine)),		set(hULine, 'Vis', 'on'),		end
		if (~isempty(hTxt)),		set(hTxt,   'Vis', 'on'),		end
		if (~isempty(hFLine))
			set(hFLine, 'Vis', 'on')
			if (~isempty(get(hFLine, 'UserData'))),		mkAnother = true;	end
		end
		pixval_stsbar('exit')
	end

	state = uisuspend_j(handles.figure1);		% Remember initial figure state
	set(handles.figure1,'Pointer', 'crosshair');

	SpectorGrant = false;		xFact = 1;
	xl = get(get(handles.axes1, 'XLabel'), 'String');	% Fish it outside to avoid error if not magnetic radial (poor patch)
	if (~isempty(xl) && strncmp(get(handles.figure1,'name'), 'Radial average', 14))	% Estimate depth to magnetic sources
		SpectorGrant = true;
		if (strcmp(xl(end-2:end-1), 'km'))		% frequency is in 1/km
			xFact = 1000;						% Multiplying factor to get depth in meters
		end
	else										% Have to check the various possibilities
		if (get(handles.check_geog, 'Val'))
			contents = get(handles.popup_selectPlot, 'Str');
			km_or_M = contents{(get(handles.popup_selectPlot,'Val'))}(end-1);
			if (km_or_M == 'm'),			xFact = 1000;	% km
			elseif (km_or_M == 'M'),		xFact = 1852;	% NM
			end
		end
	end

	w = waitforbuttonpress;
	if (w == 0)					% A mouse click
		if (strcmp(get(handles.figure1, 'Pointer'), 'arrow'))	% This might look idiot (pointer was set some lines above)
			return												% but is actually a trick to catch a not-yet-interrupted
		end														% waitforbuttonpress (from a 2 consecutive hits on toggbutton)
		button = get(handles.figure1, 'SelectionType');
		if (~strcmp(button,'normal'))							% no left-click ==> out
			set(handles.figure1,'Pointer', 'arrow')
			return
		end

		if (isempty(hULine))
			hULine = line('XData', [NaN NaN], 'YData', [0.05 0.05], 'Parent', handles.axes2,'Color','k','LineWidth',1,'Tag','UnderLine');
			hTxt = text(0, -1, 0, 'Dist= Slp=', 'Parent', handles.axes2, 'FontSize',9, 'VerticalAlignment', 'Base', 'Tag','DS');
		end
		if (isempty(hFLine))
			hFLine = line('XData', [], 'YData', [], 'Parent', handles.axes1,'Color','k','LineWidth',2,'Tag','FitLine');
		elseif (mkAnother)		% Second or above Fit lines
			hFLine = [hFLine; ...
				line('XData', [], 'YData', [], 'Parent', handles.axes1,'Color',rand(1,3),'LineWidth',2,'Tag','FitLine')];
		end
        dynSlopeFirstButtonDown(handles.figure1, handles.axes1, handles.axes2, handles.hLine, hULine,...
								hFLine, hTxt, xFact, SpectorGrant, state)
	else
        set(handles.figure1,'Pointer', 'arrow');
	end

% ------------------------------------------------------------------------------------------
function dynSlopeFirstButtonDown(hFig, hAxes1, hAxes2, hLine, hULine, hFLine, hTxt, xFact, SpectorGrant, state)
	pt = get(hAxes1, 'CurrentPoint');
	x = get(hLine,'XData');			x_lim = get(hAxes1,'XLim');
	set(hAxes2, 'Vis', 'on','XTick',[], 'YTick',[], 'xlim', x_lim, 'ylim', [-0.01 1])

	[temp,i] = min(abs(x - pt(1,1)));
	set(hFig,'WindowButtonMotionFcn',{@wbm_dynSlope, x(i), i, hAxes1, hLine, hULine, hFLine, hTxt, xFact, SpectorGrant}, ...
		'WindowButtonUpFcn',{@wbu_dynSlope, hFLine, xFact, SpectorGrant, state});

function wbm_dynSlope(obj,eventdata, x0, I0, hAxes, hLine, hULine, hFLine, hTxt, xFact, SpectorGrant)
% The SpectorGrant arg is used when estimating depth to mag sources by the Spector & Grant method
	pt = get(hAxes, 'CurrentPoint');
	X = get(hLine,'XData');       Y = get(hLine,'YData');

	[temp,i] = min(abs(X - pt(1)));
	if (i < I0),		ii = I0;			I0 = i;		i = ii;		end		% Dragging right to left
	xx = X(I0:i);		yy = Y(I0:i);
	if (SpectorGrant)
		xy = [xx(:) log(yy(:))];
	else
		xy = [xx(:) yy(:)];
	end
	N = numel(xx);
	if (N > 2),				mb = trend1d_m(xy, '-N2r', '-L');			% Do robust fit
	elseif (N == 2),		mb = trend1d_m(xy, '-N2', '-L');
	else,					return			% First point. Too soon to do anything
	end
	xUnderLine = [x0 xx(end)];
	if (~SpectorGrant)
		fstr = 'Dist=%g\t  Slope=%.3f\t (m=%.2f)';
		slp = atan(mb(1) / xFact)*180/pi;	% slope in (may be) degrees
		set(hTxt, 'Pos', [xx(1) 0.11], 'Str', sprintf(fstr, diff(xUnderLine), slp, mb(1)))
		set(hFLine(end), 'XData', [xx(1) xx(end)], 'YData', ([xx(1) xx(end)] * mb(1) + mb(2)), 'UserData', [mb slp xUnderLine])
	else
		slp = abs(mb(1) / (4*pi) * xFact);
		set(hTxt, 'Pos', [xx(1) 0.11], 'Str', sprintf('Dist=%g\t  Depth=%.0f m', diff(xUnderLine), slp))
		set(hFLine(end), 'XData', [xx(1) xx(end)], 'YData', exp([xx(1) xx(end)] * mb(1) + mb(2)), 'UserData', [mb slp xUnderLine])
	end
	set(hULine,'XData', xUnderLine)

function wbu_dynSlope(obj,event, h, xFact, SpectorGrant, state)
    uirestore_j(state, 'nochildren');				% Restore the figure's initial state
	mb_e_slp = get(h(end), 'UserData');
	if (isempty(mb_e_slp)),		return,		end		% Happens when a single click on fig
	cmenuHand = uicontextmenu('Parent',state.figureHandle);
	set(h(end), 'UIContextMenu', cmenuHand);
	if (SpectorGrant)
		uimenu(cmenuHand, 'Label', 'Slope(m/cycle) &  Intercept');
		uimenu(cmenuHand, 'Label', sprintf('%.2f   %.9g', mb_e_slp(1)/(2*pi), mb_e_slp(2)));	% Slope Intercept
		uimenu(cmenuHand, 'Label', sprintf('Depth to sources (m) = %.3f', mb_e_slp(3)));
		uimenu(cmenuHand, 'Label', 'Bandpass Filter', 'Callback', {@do_bandFilter,h(end), xFact}, 'Sep', 'on');
	else
	 	uimenu(cmenuHand, 'Label', 'Slope (atan(a0)), m  &  Intercept ');
		uimenu(cmenuHand, 'Label', sprintf('%.2f     %.3f   %.9g', mb_e_slp(3), mb_e_slp(1), mb_e_slp(2)));
	end
	uimenu(cmenuHand, 'Label', 'Recomp Slope/Intercept', 'Callback', {@recompSI,h(end), xFact, SpectorGrant}, 'Sep', 'on');
	hD = uimenu(cmenuHand, 'Label', 'Delete this line', 'Callback', 'delete(gco)', 'Sep', 'on');
	setappdata(h(end), 'xFact', xFact)		% We may need this in OpenSession
	ui_edit_polygon(h(end))

	handles = guidata(h(1));				% When on Extensional mode, plot also the faults in the Mir fig
	if (strcmp(get(handles.extensional, 'Checked'), 'on') && ~isempty(handles.handMir) && ishandle(handles.handMir.figure1))
		[r, f_x, f_y, x1, y1, x2, y2] = commonHeaves(handles, h(end));
		hL = line('XData',[x1 x2], 'YData',[y1 y2], 'Parent',handles.handMir.axes1, 'LineWidth',2, 'Tag','LinkedLine');
		setappdata(h(end), 'sister', hL)	% Store it so the delete line function can also kill the corresponding Mir line
		set(hD, 'Callback', 's=getappdata(gco,''sister'');delete(s);delete(gco)')
		draw_funs(hL, 'line_uicontext')
	end
	%dynSlope_CB(findobj('Type', 'uitoggletool', 'Tag', 'DynSlope'), [])
	pixval_stsbar(handles.figure1)			% Recreate the pixValStsBar
	set(findobj(handles.figure1, 'Tag', 'pixValStsBar'), 'Vis', 'off')		% But leave it invisible while DynSlope button is checked

function recompSI(obj,event, h, xFact, SpectorGrant)
% Recompute Slope & Intercept because line might have been edited
	x = get(h, 'XData');		y = get(h, 'YData');
	m =  (y(end) - y(1)) / (x(end) - x(1));			
	b = y(1) - m * x(1);
	child = get(get(obj,'Par'), 'Children');
	for (k = 1:numel(child))
		if (strfind(get(child(k),'Label'),'Recomp')),	K = k + 1 + SpectorGrant;	break,		end
	end
	if (SpectorGrant)
		slp = abs(m / (4*pi) * xFact);
		set(child(K), 'Label', sprintf('Depth to sources (m) =  %.3f', slp));		K = K + 1;
		set(child(K), 'Label', sprintf('%.2f   %.9g', m / (2*pi), b))		% Slope Intercept
		fstr = 'Dist=%g\t  Depth=%.3f';
	else
		slp = atan(m / xFact)*180/pi;			% Get the slope in (maybe) degrees
		set(child(K), 'Label', sprintf('%.2f     %.3f   %.9g', slp, m, b))		% Slope(deg?) Intercept
		fstr = 'Dist=%g\t  Slope=%.2f';
	end

	set(h, 'UserData', [m b slp x(1) x(end)]);
	handles = guidata(h);						% Update also the legend
	hTxt = findobj(handles.axes2,'type','text','tag','DS');
	set(hTxt,'Str',sprintf(fstr,(x(end) - x(1)),slp))
	hULine = findobj(handles.axes2,'type','Line','Tag','UnderLine');
	set(hULine,'XData', [x(1) x(end)])

	handles = guidata(h);				% When on Extensional mode, update also the fault in the Mir fig
	if (strcmp(get(handles.extensional, 'Checked'), 'on') && ~isempty(handles.handMir) && ishandle(handles.handMir.figure1))
		[r, f_x, f_y, x1, y1, x2, y2] = commonHeaves(handles, h);
		hL = getappdata(h, 'sister');
		set(hL, 'XData',[x1 x2], 'YData',[y1 y2])
	end

function do_bandFilter(obj,event, h, xFact)
% Hub function to manage the bandpass filtering
	handles = guidata(obj);
	if (isempty(handles.hMirFig))
		errordlg('DO_BANDFILTER: shouldn''t happen.','Error'),	return
	end
	if (~ishandle(handles.hMirFig))
		errordlg('Too late. You killed the figure with the original data.'),	return
	end
	warndlg('Not finished. Not working correctly. Not Not.','Warning')
	
	out = bandpass(get(h, 'XData') / xFact);
	if (isempty(out)),	return,		end

	handMir = guidata(handles.hMirFig);			% We need to fish on the original Mir fig
	[X,Y,in.Z,in.head] = load_grd(handMir);
	in.geog = handMir.geog;
	in.hMirFig = handMir.figure1;
	in.bandpass = out;
	in.mode = 'bpass';
	
	fft_stuff(in)
% --------------------------------------------------------------------------------------------------

% ------------------------------------------------------------------------------------------
function make_scatterPlot(obj, evt)
% Find the two lines whose tag is CMOP and make a scatter plot with eventual interpolation
	handles = guidata(obj);
	hLines = findobj(handles.axes1, 'type', 'line', 'tag', 'CMOP');
	if (numel(hLines) ~= 2)
		errordlg('Ops, something went wrong with this option programming.','Error'),	return
	end
	x1 = get(hLines(1), 'XData');	y1 = get(hLines(1), 'YData');
	x2 = get(hLines(2), 'XData');	y2 = get(hLines(2), 'YData');
	if (numel(x1) < numel(x2))
		y2 = interp1(x2,y2,x1);		% Reinterpolate to fit the smaller dataset
	elseif (numel(x1) > numel(x2))
		y1 = interp1(x1,y1,x2);		
	else
		% nothing. They are equal sized
	end

	hf = ecran(y1, y2, 'Scatter plot');
	newHand = guidata(hf);
	hLine = findobj(newHand.axes1, 'type', 'line');
	set(hLine,'LineStyle', 'none', 'Marker', '.')

% ------------------------------------------------------------------------------------------
function outliers_clean(obj, evt, h)
% Filter outliers by replacing them with interpolated values
	handles = guidata(h);
	x = get(h,'XData');		y = get(h,'YData');
	ind = find(diff(x) == 0);
	if (~isempty(ind))							% Means we have repeated X that would screw the interp1 step
		x(ind) = [];	y(ind) = [];
		handles.data(ind,:) = [];
		guidata(handles.figure1, handles);
	end
	indNaN = isnan(y);
	if (any(indNaN))
		y(indNaN) = interp1(x(~indNaN), y(~indNaN), x(indNaN), 'linear','extrap');
	end
	[pp,p] = spl_fun('csaps',x,y);				% To get csaps's p estimate
	yy = spl_fun('csaps',x,y,p*0.95,x);
	difa = abs(y - yy);
	ind = (difa > 2*std(difa));

	if (any(ind))
		y(ind) = interp1(x(~ind), y(~ind), x(ind));
	end
	if (any(indNaN)),	y(indNaN) = NaN;	end	% Restore the original holes (NaNs)
	set(h, 'XData',x, 'YData', y)
	if (size(handles.data,2) == 3)				% In this case we need to update Z column too (saved in Sessions)
		handles.data(:,3) = y;
		guidata(handles.figure1, handles);
	end

% ------------------------------------------------------------------------------------------
function do_histogram(obj, evt, h, tipo)
% Show an histogram of the yy data
	y = get(h, 'YData');
	if (strcmp(tipo, 'Hist'))
		this_name = get(get(get(h, 'Parent'), 'Parent'), 'Name');
		n_bins = sshist(y);			% Automatic bining
		hFig = ecran;				% Create a new Ecran Fig to hold the histogram
		delete(findobj(hFig, 'Tag', 'isocs_but'))	% Others uis should be removed too
		set(hFig, 'Name', ['Histogram of ' this_name])
		hP = histo_m('hist', y, n_bins, 'hands');
		set(hP, 'Tag', 'Histogram')	% To be used by write_gmt_script
		setappdata(hP, 'xy', y)		% Store it for use in write_gmt_script
	else
		hP = histo_m('bar', get(h, 'XData'), y);
		set(hP, 'Tag', 'BarGraph')	% To be used by write_gmt_script
		set(h, 'Visible', 'off')	% Instead of deleting it?
	end

% ------------------------------------------------------------------------------------------
function pick_onLines2reference(obj, evt)
% Entry function for setting GCP type markers on the two lines, of which one will later be
% pice-wise 'referenced' to the other.

	handles = guidata(obj);
	hLines = findobj(handles.axes1,'type','line');		% Fish handles of the two working curves
	if (isempty(handles.hMarkerToRef))
		handles.hMarkerToRef(1) = line('Parent',handles.axes1,'XData',[], 'YData',[], 'Marker','o', 'MarkerSize',7,'LineStyle','none');
		handles.hMarkerToRef(2) = line('Parent',handles.axes1,'XData',[], 'YData',[], 'Marker','o', 'MarkerSize',7,'LineStyle','none');
		handles.lastMarkedLine = 0;			% Flag to store info on which line was inserted the last marker
		handles.toRefCount = zeros(2,1);
		guidata(handles.figure1,handles)
	else
		% Here 'hLines' contains also the Marker handles, which we don't want
		ind1 = (hLines == handles.hMarkerToRef(1));
		ind2 = (hLines == handles.hMarkerToRef(2));
		hLines(ind1 | ind2) = [];			% There should be only 2 now
	end
	if (numel(hLines) ~= 2)
		errordlg(sprintf('Error in function pick_onLines2reference. Number of lines = %d\n', numel(hLines)),'ERROR')
	end

	if (strcmp(get(obj,'State'),'on'))
		handles.state = uisuspend_j(handles.figure1);			% Remember initial figure state
		guidata(handles.figure1,handles)
		set(handles.figure1,'WindowButtonDownFcn',{@add_refMarkers, obj, hLines}, 'pointer','crosshair')
	else
	    uirestore_j(handles.state, 'nochildren');				% Restore the figure's initial state
	end

function add_refMarkers(obj, evt, hToggle, hLines)
% Add makers to the pair of lines, 'Master & Slave' -- in the GCP terminology

	handles = guidata(obj);
	button = get(handles.figure1, 'SelectionType');
	if (strcmp(button,'alt')) || (strcmp(button,'extend')) || (strcmp(button,'open'))
		set(hToggle, 'State', 'off')
	    uirestore_j(handles.state, 'nochildren');				% Restore the figure's initial state
		% We still need to find which of the line Markers is attached to 'hLineToRef'
		% We'll do it by relying on the minimum distance along Y of first pt of both markers to that line
		yRef = get(handles.hLineToRef,'YData');
		y1 = get(handles.hMarkerToRef(1),'YData');		y2 = get(handles.hMarkerToRef(2),'YData');
		min1 = min(abs(yRef - y1(1)));					min2 = min(abs(yRef - y2(1)));
		[lix, ind] = min([min1 min2]);		% Pick the one with smallest minimum
		cmenuHand = uicontextmenu('Parent',handles.figure1);
		set(handles.hMarkerToRef(ind),'UIContextMenu', cmenuHand);
		uimenu(cmenuHand, 'Label', 'Reference me', 'Callback', {@do_reference, ind});
		return
	end

	% Get the two candidates clicked pts
	[pt_x(1), pt_y(1), x_off(1), minDist(1)] = get_pointOnLine(handles.axes1, hLines(1));
	[pt_x(2), pt_y(2), x_off(2), minDist(2)] = get_pointOnLine(handles.axes1, hLines(2));

	[lix, ind] = min(minDist);		% Pick the one with shortest minDist

	x = get(handles.hMarkerToRef(ind),'XData');		y = get(handles.hMarkerToRef(ind),'YData');
	ud = get(handles.hMarkerToRef(ind),'UserData');
	dp = abs(diff(handles.toRefCount));
	if ((dp == 0 || dp < 2) && (ind ~= handles.lastMarkedLine) )	% Add one marker
		x = [x pt_x(ind)];		y = [y pt_y(ind)];
		ud = [ud x_off(ind)];
		handles.toRefCount(ind) = handles.toRefCount(ind) + 1;
	else							% Replace last marker 
		n = numel(x);
		if (n == 0),		handles.toRefCount(ind) = handles.toRefCount(ind) + 1;		end
		n = max(n, 1);				% So the logic applies also to first pt, when x = []
		x(n) = pt_x(ind);	y(n) = pt_y(ind);	ud(n) = x_off(ind);
	end
	handles.lastMarkedLine = ind;	% Save this info for usage in next clicking-round

	cor = [200 0 0; 0 200 0] / 255;		% Colors of symbols on each line
	set(handles.hMarkerToRef(ind),'XData',x, 'YData',y, 'MarkerFaceColor', cor(ind,:), 'UserData', ud)
	
	guidata(handles.figure1,handles)

function do_reference(obj, evt, ind)
% Do a piecewise stretching of the line-to-reference (handles.hLineToRef)
% IND is the index (1 or 2) of Markers line (hMarkerToRef) attached to the to-be-referenced line

	handles = guidata(obj);
	x = get(handles.hLineToRef,'XData');		y = get(handles.hLineToRef,'YData');	
	offset_2ref  = get(handles.hMarkerToRef(ind),'UserData');

	if (ind == 1)
		xMarker_ref = get(handles.hMarkerToRef(2),'XData');
	else
		xMarker_ref = get(handles.hMarkerToRef(1),'XData');
	end
	
	for (k = 1:numel(xMarker_ref)-1)
		dx = xMarker_ref(k+1) - x(offset_2ref(k+1));	% Distance between the 2 end points of this segment on ref & to-ref Markers
		f = (xMarker_ref(k+1) - xMarker_ref(k)) / (x(offset_2ref(k+1)) - x(offset_2ref(k)));	% Piecewise factor
		x(offset_2ref(k):offset_2ref(k+1)) = (x(offset_2ref(k):offset_2ref(k+1)) - x(offset_2ref(k))) * f + xMarker_ref(k);
		if (offset_2ref(k+1) < numel(x))
			x(offset_2ref(k+1)+1:end) = x(offset_2ref(k+1)+1:end) + dx;		% Shift all remaining points of DX distance
		end
	end
	if (offset_2ref(1) > 1)		% We have still to move the chunk x(1,offset_2ref(1)-1)
		x(1,offset_2ref(1)-1) = x(1,offset_2ref(1)-1) + xMarker_ref(1) - x(offset_2ref(1));
	end

	ecran('reuse',x,y,[],'Referenced')	
% --------------------------------------------------------------------------------------------------

% --------------------------------------------------------------------------------------------------
function pick_CB(obj, evt)
% ...
	handles = guidata(obj);
	o = findobj('Type','uitoggletool', 'Tag', 'DynSlope');
	if (strcmp(get(o,'State'),'on'))		% If DynSlope is 'on' turn it off
		set(o,'State','off'),		dynSlope_CB(o, [])
	end
	if (strcmp(get(obj,'State'),'on'))
		set(handles.figure1,'WindowButtonDownFcn',{@add_MarkColor,obj}, 'pointer','crosshair')
	else
		set(handles.figure1,'WindowButtonDownFcn','','pointer','arrow')	
	end

% --------------------------------------------------------------------------------------------------
function add_MarkColor(obj, evt, h)
% Add a red Marker over the closest (well, near closest) clicked point.
% H is the handle to the uitogglebutton

	handles = guidata(obj);				% get handles
	button = get(handles.figure1, 'SelectionType');
	if (~strcmp(button,'normal'))		% If not left-click, stop.
		set(h, 'State', 'off')
		set(handles.figure1,'WindowButtonDownFcn','','pointer','arrow')
		return
	end
	
  	[pt_x, pt_y, x_off] = get_pointOnLine(handles.axes1, handles.hLine);

	hM = findobj(handles.figure1,'Type','Line','tag','marker');
	xr = get(hM,'XData');		yr = get(hM,'YData');
	id = find(xr == pt_x);
	if (isempty(id))            % New Marker
		if (~isempty(handles.handMir) && ishandle(handles.handMir.figure1))
			% Get the X,Y coordinates to plot this point in the Mirone figure
			% We need to add x_off since "i" counts only inside the +/- 1/10 of x_lim centered on current point
			mir_pt_x = handles.data(x_off,1);		mir_pt_y = handles.data(x_off,2);
			hLine = handles.hLine;
			if (numel(hLine) > 1),	hLine = gco;	end		% Happens when we have an RGB triplet from track
			h = line(mir_pt_x, mir_pt_y,'Parent',handles.handMir.axes1,'Marker','o','MarkerFaceColor',get(hLine,'Color'), ...
				'MarkerEdgeColor','k', 'MarkerSize',6,'LineStyle','none', 'Tag','LinkedSymb');
			try
				% Now get the color of the spot in the Mirone image and make the symbol color the complement of that 
				img = get(handles.handMir.hImg, 'CData');
				row = round(getPixel_coords(size(img,1), get(handles.handMir.hImg,'YData'),mir_pt_y));
				col = round(getPixel_coords(size(img,2), get(handles.handMir.hImg,'XData'),mir_pt_x));
				if (ndims(img) == 2)
					c = img(row,col);
					cmap = get(handles.handMir.figure1, 'colormap');
					c = cmap(c,:);
				else
					c = double([img(row,col,1) img(row,col,2) img(row,col,3)]) / 255;
				end
				set(h, 'MarkerFaceColor', 1-c)
			end
			draw_funs(h,'DrawSymbol')		% Set uicontexts
		end

		if (isempty(hM))        % First red Marker on this axes
			line(pt_x, pt_y,'Marker','s','MarkerFaceColor','r','MarkerSize',5,'LineStyle','none','Tag','marker','UserData',h);
		else
			xr = [xr pt_x];     yr = [yr pt_y];
			set(hM,'XData',xr, 'YData', yr)
			ud = get(hM,'UserData');
			set(hM,'UserData', [ud h]);		% Save the Mirone symbol handle here
		end
		if (strcmp(get(handles.FileSaveRedMark,'Vis'), 'off'))		% Un-hide the file saving option
			set(handles.FileSaveRedMark,'Vis','on')
		end
	else                        % Marker already exists. Kill it
		xr(id) = [];            yr(id) = [];
		set(hM,'XData',xr, 'YData', yr)
		ud = get(hM,'UserData');
		try		delete(ud(id)),		end
		ud(id) = [];
		set(hM,'UserData', ud)
		if (isempty(xr))		% No more markers, so hide the possibility of saving them
			set(handles.FileSaveRedMark,'Vis','off')
		end
	end

% -------------------------------------------------------------------------------------
function pix_coords = getPixel_coords(img_length, XData, axes_coord)
% Convert coordinates from axes (real coords) to image (pixel) coordinates.
% IMG_LENGTH is the image width (n_columns)
% XDATA is the image's [x_min x_max] in axes coordinates
% AXES_COORD is the (x,y) coordinate of the point(s) to be converted

	slope = (img_length - 1) / (XData(end) - XData(1));
	if ((XData(1) == 1) && (slope == 1))
		pix_coords = axes_coord;
	else
		pix_coords = slope * (axes_coord - XData(1)) + 1;
	end
% --------------------------------------------------------------------------------------------------
function [pt_x, pt_y, x_off, minDist] = get_pointOnLine(hAxes, hLine, y)
% Find the coordinates of the closest point on line to the clicked pt
% Y ... don't remember anymore why originaly it was fetch from handles.data(:,3)
%		Anyway, if not transmitted, we fish it from the line handle.
%
% X_OFF		holds the index of that point on the line array
% MINDIST	The minimum distance between the clickage and the picked point on line

	if (numel(hLine) > 1)
		hLine = gco;
	end
	if (nargin == 2),		y = get(hLine,'YData')';	end
	x = get(hLine,'XData')';
	pt = get(hAxes, 'CurrentPoint');

	x_lim = get(hAxes,'XLim');			y_lim = get(hAxes,'YLim');
	dx = diff(x_lim) / 20;					% Search only betweem +/- 1/10 of x_lim
	id = (x < (pt(1,1)-dx) | x > (pt(1,1)+dx));
	x(id) = [];				y(id) = [];		% Clear outside-2*dx points to speed up the search code
	XScale = diff(x_lim);	YScale = diff(y_lim);

	r = sqrt(((pt(1,1)-x) ./ XScale).^2 + ((pt(1,2)-y) ./ YScale).^2);
	[minDist, i] = min(r);
	pt_x = x(i);				pt_y = y(i);
	x_off = find(~id);
	x_off = x_off(1) + i - 1;	% Get the index of the first non killed x element

% --------------------------------------------------------------------------------------------------
function isocs_CB(obj, evt)
% 'Click' callback function to deal with the Mag Bar code
	handles = guidata(obj);
	if (strcmp(get(obj,'State'),'on'))		% Show magnetic UIs at the base and hide the distance/coords ones
		set([handles.check_geog handles.popup_selectPlot handles.popup_selectSave], 'Vis','off')
		set([handles.edit_startAge handles.edit_ageEnd handles.push_magBar handles.text_startAge ...
			handles.text_endAge], 'Vis','on')
		if (~isempty(handles.hPatchMagBar))
			set([handles.hTxtChrons(:); handles.hPatchMagBar; handles.push_syntheticRTP], 'Vis', 'on')
			if (~isempty(handles.hSynthetic))
				set([handles.push_ageFit handles.slider_filter], 'Vis','on')
				if (~isempty(handles.syntPar))		% Values were transmitted via OPTcontrol
					set(handles.popup_ageFit, 'Vis','on')
				else
					set(handles.edit_ageFit, 'Vis','on')
				end
			end
		end
	else
		if (handles.show_popups)			% Make next fellows visible only when apropriate
			set([handles.check_geog handles.popup_selectPlot handles.popup_selectSave], 'Vis','on')
		end
		set([handles.edit_startAge handles.edit_ageEnd handles.push_magBar handles.text_startAge ...
			handles.check_zeroAge handles.text_endAge handles.push_syntheticRTP], 'Vis','off')
		set([handles.push_ageFit handles.slider_filter handles.popup_ageFit handles.edit_ageFit], 'Vis','off')
		if (~isempty(handles.hPatchMagBar))
			set([handles.hTxtChrons(:); handles.hPatchMagBar; handles.push_syntheticRTP], 'Vis', 'off')
		end
	end

% --------------------------------------------------------------------------------------------------
function legend_CB(obj, evt, opt)
% 'Click' callback function to deal with Legends
% OPT is used when recreating the legend (needed when extra lines were plotted after legend creation)
	handles = guidata(obj);
	if (strcmp(get(obj,'State'),'on'))
		if (isempty(handles.hLegend))
			%hLines = findobj(handles.axes1, 'type','line');
			str = cell(numel(handles.hLine),1);
			for (k = 1:numel(handles.hLine))
				t = getappdata(handles.hLine(k), 'DisplayName');
				if (~isempty(t)),	str{k} = t;
				else,				str{k} = sprintf('%d',k);
				end
			end
			[handles.hLegend, handles.hLegLabels] = legend_(handles.axes1, str);
			guidata(handles.figure1, handles)
		else
			if (nargin == 2)
				set(findobj(handles.hLegend), 'Vis', 'on')
			else					% Here we must update an existing Legend. Kill old and recreate
				for (k = 1:numel(handles.hLegLabels))
					if (strcmp(get(handles.hLegLabels(k), 'Type'), 'text'))
						oldLabels = get(handles.hLegLabels(k), 'Str');	% Either a char, char matrix or a cell (if edited)
						break
					end
				end
				delete(handles.hLegend)
				%hLines = findobj(handles.axes1, 'type','line');
				if (isa(oldLabels, 'char')),	oldLabels = cellstr(oldLabels);		end
				oldLabels{end+1} = num2str(numel(handles.hLine));
				[handles.hLegend, handles.hLegLabels] = legend_(handles.axes1, oldLabels);
				guidata(handles.figure1, handles)
			end
		end
	else
		set(findobj(handles.hLegend), 'Vis', 'off')
	end

% -------------------------------------------------------------------------------
function check_geog_CB(hObject, handles)
	if get(hObject,'Value')
		set(handles.popup_selectPlot,'String',{'Horizontal coords (data units)';
			'Horizontal coords (km)';'Horizontal coords (NM)'; 'Horizontal coords (m)'});
		set(handles.popup_selectSave,'String',{'Save Line on disk';'Distance,Z (data units, text)';
			'Distance,Z (data units, binary)';'Distance,Z (km, text)';'Distance,Z (km, binary)';
			'Distance,Z (NM, text)';'Distance,Z (NM, binary)';
			'X,Y,Z (data units, text)';'X,Y,Z (data units, binary)'});
	else
		set(handles.popup_selectPlot,'String','Horizontal coords (data units)','Value',1);
		set(handles.popup_selectSave,'String',{'Save Line on disk';'Distance,Z (data units, text)';
			'Distance,Z (data units, binary)';'X,Y,Z (data units, text)';'X,Y,Z (data units, binary)'},'Value',1);
	end

% ---------------------------------------------------------------------------------
function popup_selectPlot_CB(hObject, handles)
	val = get(hObject,'Value');     str = get(hObject, 'String');
	geog = true;
	switch str{val}
		case 'Horizontal coords (data units)'	% Compute the accumulated distance along line in data units
			units = 'u';	geog = false;
		case 'Horizontal coords (km)'			% Compute the accumulated distance along line in km
			units = 'km';
		case 'Horizontal coords (m)'			% Compute the accumulated distance along line in m
			units = 'm';
		case 'Horizontal coords (NM)'			% Compute the accumulated distance along line in Nmiles
			units = 'nm';
	end
	rd = get_distances(handles.data(:,1), handles.data(:,2), geog, units, handles.ellipsoide);
	set(handles.hLine,'XData',rd);
	axis(handles.axes1,'tight');
	guidata(hObject, handles);

% ---------------------------------------------------------------------------------
function popup_selectSave_CB(hObject, handles)
	val = get(hObject,'Value');     str = get(hObject, 'String');
	switch str{val}
		case 'Save Line on disk'
		case 'Distance,Z (data units, text)'					% Save profile in ascii data units
			[FileName,PathName] = put_or_get_file(handles,{'*.dat', 'Dist Z (*.dat)'; '*.*', 'All Files (*.*)'},'Distance,Z (ascii)','put','.dat');
			if isequal(FileName,0),		set(hObject,'Value',1),		return,		end     % User gave up
			double2ascii([PathName FileName],[handles.dist handles.data(:,3)],'%f\t%f');
		case 'Distance,Z (data units, binary)'				% Save profile in binary data units
			[FileName,PathName] = put_or_get_file(handles,{'*.dat', 'Dist Z (*.dat)'; '*.*', 'All Files (*.*)'},'Distance,Z (binary float)','put');
			if isequal(FileName,0),		set(hObject,'Value',1),		return,		end     % User gave up
			fid = fopen([PathName FileName],'wb');
			fwrite(fid,[handles.dist handles.data(:,3)]','float');  fclose(fid);
		case 'Distance,Z (km, text)'							% Save profile in ascii (km Z) 
			[FileName,PathName] = put_or_get_file(handles,{'*.dat', 'Dist Z (*.dat)'; '*.*', 'All Files (*.*)'},'Distance (km),Z (ascii)','put','.dat');
			if isequal(FileName,0),		set(hObject,'Value',1),		return,		end     % User gave up
			rd = get_distances(handles.data(:,1), handles.data(:,2), true, 'k', handles.ellipsoide);
			double2ascii([PathName FileName],[rd handles.data(:,3)],'%f\t%f')
		case 'Distance,Z (km, binary)'						% Save profile in binary (km Z) 
			[FileName,PathName] = put_or_get_file(handles,{'*.dat', 'Dist Z (*.dat)'; '*.*', 'All Files (*.*)'},'Distance (km),Z (binary float)','put');
			if isequal(FileName,0),		set(hObject,'Value',1),		return,		end     % User gave up
			rd = get_distances(handles.data(:,1), handles.data(:,2), true, 'k', handles.ellipsoide);
			fid = fopen([PathName FileName],'wb');
			fwrite(fid,[rd handles.data(:,3)]','float');  fclose(fid);
		case 'Distance,Z (NM, text)'							% Save profile in ascii (NM Z) 
			[FileName,PathName] = put_or_get_file(handles,{'*.dat', 'Dist Z (*.dat)'; '*.*', 'All Files (*.*)'},'Distance (m),Z (ascii)','put','.dat');
			if isequal(FileName,0),		set(hObject,'Value',1),		return,		end     % User gave up
			rd = get_distances(handles.data(:,1), handles.data(:,2), true, 'n', handles.ellipsoide);
			double2ascii([PathName FileName],[rd handles.data(:,3)],'%f\t%f')
		case 'Distance,Z (NM, binary)'						% Save profile in binary (NM Z) 
			[FileName,PathName] = put_or_get_file(handles,{'*.dat', 'Dist Z (*.dat)'; '*.*', 'All Files (*.*)'},'Distance (m),Z (binary float)','put');
			if isequal(FileName,0),		set(hObject,'Value',1),		return,		end     % User gave up
			rd = get_distances(handles.data(:,1), handles.data(:,2), true, 'n', handles.ellipsoide);
			fid = fopen([PathName FileName],'wb');
			fwrite(fid,[rd handles.data(:,3)]','float');  fclose(fid);
		case 'X,Y,Z (data units, text)'						% Save profile in ascii (km Z) 
			[FileName,PathName] = put_or_get_file(handles,{'*.dat', 'x,y,z (*.dat)';'*.*', 'All Files (*.*)'},'X,Y,Z (ascii)','put','.dat');
			if isequal(FileName,0),		set(hObject,'Value',1),		return,		end     % User gave up
			double2ascii([PathName FileName],[handles.data(:,1) handles.data(:,2) handles.data(:,3)],'%f\t%f\t%f')
		case 'X,Y,Z (data units, binary)'						% Save profile in binary (km Z) 
			[FileName,PathName] = put_or_get_file(handles,{'*.dat', 'x,y,z (*.dat)';'*.*', 'All Files (*.*)'},'X,Y,Z (binary float)','put');
			if isequal(FileName,0),		set(hObject,'Value',1),		return,		end     % User gave up
			fid = fopen([PathName FileName],'wb');
			fwrite(fid,[handles.data(:,1) handles.data(:,2) handles.data(:,3)]','float');  fclose(fid);
	end
	set(hObject,'Value',1);

% --------------------------------------------------------------------
function FileExport_CB(hObject, handles)
	filemenufcn(handles.figure1,'FileExport')

% --------------------------------------------------------------------
function FilePrint_CB(hObject, handles)
	if (ispc),		print -v
	else,			print
	end

% --------------------------------------------------------------------
function FileOpen_CB(hObject, handles)
% Read the file and select which columns to plot
%
% Section to deal with cases where time is provided in data time char srtrings
% In that case first line of file must be of this form (the time format may change)
% # DATENUM dd-mm-yyyy HH:MM:SS
%
% The special cases # DATENUM YYYY.MM and YYYY.XX (decimal years) is also handled (for data output
% from Aquamoto) but in this case the file must have only 2 columns - (time, data)
%
% # DATENUM SECONDS and DAYS assume seconds (days) since 1 Jan 0000
% # DATENUM RATA days since 0000-12-31T00:00:00
% # DATENUM UNIX seconds since 1970-01-01T00:00:00
%
% Another special case is # DATENUM YYYYDOY (for data output from Slices) where the file
% must have two columns - (time_as_Day-Of-Year, data). Note that YYYY must be replaced by
% the year in question. Example: # DATENUM 2012DOY
%
% Another special case is provided when a comment line is # TO_REFERENCE OFFSET=XX SCALE=XX
% This will scale X coords as (X - X(1)) * scale + offset and also activate an option to
% register this line with respect to a reference line.
%
% Special cases # MAREG or # MAREG_D or # MAREG_H when the file has only two columns and first
% holds the time in: decimal days (first two cases) or decimal hours (third case)

	str1 = {'*.dat;*.DAT;', 'Data files (*.dat,*.DAT)';'*.*', 'All Files (*.*)'};
	[FileName, PathName, handles] = put_or_get_file(handles,str1,'Select input data','get');
	if isequal(FileName,0),		return,		end	
	fname = [PathName FileName];

	isDateNum = false;		got_toReference = false;
	fid = fopen(fname);
	H1 = fgetl(fid);
	if (isempty(H1))
		errordlg('this file is empty. Bye.','Error'),	return
	end
	if (H1(1) == '#')
		ind = strfind(H1, '# DATENUM');		ind_mareg = strfind(H1, '# MAREG');

		if (isempty(ind) && isempty(ind_mareg))		% Just a ignorant comment line
			fclose(fid);
		else
			% In either case we need to execute this chunk of common code
			todos = fread(fid,'*char');
			fclose(fid);
			[bin,n_cols,multi_seg,n_headers] = guess_file(fname);
			if (n_headers > 1)
				id = strfind(todos(1:(n_headers - 1)*120)',sprintf('\n'));
				todos = todos(id(n_headers)+1:end);		% Jump the header lines
			end
		end

		if (~isempty(ind))				% The DATENUM case
			t = strtok(H1(ind(1)+10:end));
			if (n_cols == 3)
				[yymmdd, hhmm, sl] = strread(todos,'%s %s %f');
				yymmdd = strcat(yymmdd, repmat({char(32)}, size(yymmdd,1),1), hhmm);	%BUG {char(' ')} is ignored
			else
				if (strncmpi(t,'YYYY.X',6) || strncmpi(t,'DAY',3) || strncmpi(t,'SEC',3))
					[yymmdd, sl] = strread(todos,'%f %f', 'delimiter', '\t');
				else
					[yymmdd, sl] = strread(todos,'%s %f', 'delimiter', '\t');
				end
			end
			try
				if (strcmpi(t,'YYYY.MM'))			% Local form sometimes output from Aquamoto
					Y = str2double(yymmdd);			% Works for vectors as long as argument is a cell
					M = (Y - fix(Y)) * 100;
					Y = fix(Y);
					D = ones(numel(M), 1) * 15;		% half month in this aproximation
					serial_date = datenum(Y, M, D);
				elseif (strncmpi(t,'YYYY.X',6))		% Also Local form sometimes output from Aquamoto (Decimal years)
					Y = fix(yymmdd);
					dec = (yymmdd - Y);
					days_in_year = (datenum(Y+1,1,1) - datenum(Y,1,1)) .* dec;
					serial_date = datenum(Y,1,1) + days_in_year;
				elseif (strncmpi(t,'Seconds since 0000-01-01',24))		% Seconds since 1 Jan 0000
					serial_date = yymmdd / 86400;
				elseif (strncmpi(t,'unix',4))		% Seconds since 1970-01-01T00:00:00
					serial_date = yymmdd / 86400 + datenum('01-Jan-1970');
				elseif (strncmpi(t,'RATA',4))		% Days since 0000-12-31T00:00:00
					serial_date = yymmdd + 365;
				elseif (strncmpi(t,'DAY',3))		% Assumed to be days since 1 Jan 0000
					serial_date = yymmdd;
				elseif (strcmpi(t(5:7),'DOY'))		% YYYYDOY Local form sometimes output from Slices
					Y = str2double(t(1:4));
					DOY = str2double(yymmdd);
					serial_date = datenum(Y, 1, 1) + DOY;
				else
					if (~isnan(str2double(t)))		% Interpret 't' as a dateform number
						t = str2double(t);
					else
						t = H1(ind(1)+10:end);		% t is date time format string
					end
					serial_date = datenum(yymmdd, t);
				end
			catch
				errordlg(lasterr,'Error'),		return
			end
			data = [serial_date sl];
			out = [1 2];						% To simulate the output of select_cols
			isDateNum = true;

		elseif (~isempty(ind_mareg))			% The MAREG case
			[serial_date, sl] = strread(todos,'%f %f', 'delimiter', '\t');	% What if n_cols ~= 2?
			time_is_hh = false;					% i.e time is assumed to be decimal day
			if ((numel(H1) >= 9) && strcmpi(H1(8:9), '_H'))		% Got oen decimal hours case
				time_is_hh = true;
			end
			if (time_is_hh)
				serial_date = serial_date / 24;
			end
			difa = diff(serial_date);
			difa2 = abs(diff(difa));
			if (max(difa2) > 0.001)				% Need to reinterpolate. 1e-3 of a day is close to 1.5 min
				if (min(difa) <= 0)
					errordlg('Error: Ai Ai. Time is not monotonically increasing','Error'),		return
				end
				min_step = median(difa);
				X = (serial_date(1):min_step:serial_date(end))';
				sl = interp1(serial_date,sl,X);
				serial_date = X;
			end
			data = [serial_date sl];
			out = [1 2];						% To simulate the output of select_cols
			isDateNum = true;
		end
	else
		fclose(fid);
	end

	if (~isDateNum)				% Means data was not yet read
		[bin, n_column, multi_seg, n_headers] = guess_file(fname);
		if (bin)
			errordlg('Reading binary files is not yet implemented here', 'Error'),		return
		end
		if (multi_seg)
			[data, lix, lix, lix, out] = text_read(fname,NaN,n_headers,'>');
		else
			[data, lix, lix, lix, out] = text_read(fname,NaN,n_headers);
		end
		%[data, lix, lix, lix, out] = text_read(fname);
		if (~isa(data, 'cell') && (isempty(data) || size(data,2) == 1))
			errordlg('File doesn''t have any recognized nymeric data (Quiting) or one column only.','Error');
			return
		end

		% Check if it exists a comment line of the type # TO_REFERENCE OFFSET=XX SCALE=XX
		% If yes, scale X coords as (X - X(1)) * scale + offset
		% Use this, for example, when importing data where X is distance (e.g. cm) and want to convert to time
		if (~isempty(out) && ~isempty(out.headers))
			got_it_at_row = 0;
			for (k = 1:numel(out.headers))
				ind = strfind(out.headers{k}, 'TO_REFERENCE');
				if (~isempty(ind))
					got_it_at_row = k;
					break
				end
			end
			if (got_it_at_row)				% YES, we got one of those files
				[t, r] = strtok(out.headers{got_it_at_row}(ind(1)+13:end));
				ind1 = strfind(t,'SCALE=');		ind2 = strfind(r,'OFFSET=');
				if (isempty(ind1) && isempty(ind2))		% Allow also the OFFSET=XX SCALE=XX combination
					ind1 = strfind(r,'SCALE=');		ind2 = strfind(t,'OFFSET=');
					tmp  = t;	t = r;		r = tmp;	% Bubble sort the token/remainder
				end
				
				scale = NaN;	offset = NaN;
				if (~isempty(ind1) && ~isempty(ind2))
					scale  = sscanf(t(ind1(1)+6:end), '%f');
					offset = sscanf(r(ind2(1)+7:end), '%f');
				end
				if (any(isnan([scale offset])))
					warndlg('Badly formated line to instruct the scaling/offset of imported file.','WarnError')
				else
					% SCALE X distance from first to last point and add OFFSET
					data(:,1) = (data(:,1) - data(1,1)) * scale + offset;
					got_toReference = true;		% Use later to signal that this is a particular type of line
				end
			end
		end
		% -----------------------------------------------------------------------------------------------------

		if (multi_seg),		data_ = data{1};
		else,				data_ = data;
		end
		if (size(data_, 2) > 2)			% If file has more than 2 cols, call the col selection tool
			out = select_cols(data_, 'xy', fname, 1000);	% If multi-seg only first one is used.
			if (isempty(out)),		return,		end
		else
			out = [1 2];
		end
	end

	if (numel(out) == 4)				% x,y,z but first two are to compute distance
		if (multi_seg),		data = data{1};		end		% Only first first segment is used
		geog = aux_funs('guessGeog', [min(data(:,1)) max(data(:,1)) min(data(:,2)) max(data(:,2))]);
		units = handles.measureUnit;
		if (geog),	units = 'k';	end
		rd = get_distances(data(:,out(1)), data(:,out(2)), geog, units, handles.ellipsoide);
		handles.dist = rd;				% Save it in case user wants to save it to file
		handles.hLine = line('Parent',handles.axes1,'XData',rd, 'YData',data(:,out(3)));
	else
		nPrevLines = numel(handles.hLine);
		if (multi_seg > 1 || isa(data, 'cell'))
			handles.hLine = [handles.hLine zeros(1, numel(data))];
			for (k = 1:numel(data))
				handles.hLine(k+nPrevLines) = line('Parent',handles.axes1,'XData',data{k}(:,out(1)),'YData',data{k}(:,out(2)));
			end
		else
			handles.hLine(nPrevLines+1) = line('Parent',handles.axes1,'XData',data(:,out(1)),'YData',data(:,out(2)));
		end
	end

	draw_funs([], 'set_line_uicontext_XY', handles.hLine, 'main')		% Set lines's uicontextmenu
	finish_line_uictx(handles.hLine)		% Assign the callbacks to menus only declared by draw_funs()

	set(handles.figure1,'Name',fname)
	axis(handles.axes1,'tight');
	c_order = get(handles.axes1,'ColorOrder');
	for (k = 1:numel(handles.hLine))
		nc = rem(handles.n_plot+k,7);     % recycle through the default colors
		if (nc == 0),	nc = 7;		end
		set(handles.hLine(k),'Color', c_order(nc,:))
	end
	handles.n_plot = handles.n_plot + numel(handles.hLine);

	% ...
	handles.hLineToRef = [];			% Initialize it
	if (got_toReference)				% Make a copy of the toRef line handle
		handles.hLineToRef = handles.hLine;
	end
	if (~isempty(handles.hLineToRef) && (handles.n_plot > 1))
		h = findobj(handles.figure1, 'type', 'uitoggletool', 'Tag', 'DynSlope');
		set(h, 'Click',@pick_onLines2reference, 'Tooltip','Pick points alternately on the two lines to later reference')
	end

	if (multi_seg > 1 || isa(data, 'cell'))
		handles.data = [data{1}(:,out(1)) data{1}(:,out(2))];	% NOTE, Only this line is saveable. MUST REMOVE THIS OLD SHIT
	else
		handles.data = [data(:,out(1)) data(:,out(2))];			% NOTE, if handles.n_plot > 1 only last data is saved
	end
	guidata(hObject, handles);
	if (isDateNum)
		add_uictx_CB(handles.add_uictx, handles)
	end

	if (~isempty(handles.hLegend))		% If we already have a legend, add one more entry for this file
		obj = findobj(handles.figure1, 'Tag', 'Legend');
		legend_CB(obj, [], '+')
	end

% --------------------------------------------------------------------
function FileSave_CB(hObject, handles)
	if (isempty(handles.hLine)),	return,		end
	[FileName,PathName] = put_or_get_file(handles,{'*.dat', 'X,Y (*.dat)';'*.*', 'All Files (*.*)'},'X,Y (ascii)','put', '.dat');
	if isequal(FileName,0),		return,		end     % User gave up	
	[x, y] = get_inside_rect(handles);
	double2ascii([PathName FileName],[x(:) y(:)],'%f\t%f');

% --------------------------------------------------------------------
function FileSaveRedMark_CB(hObject, handles)
% Save the red markers in file
	[FileName,PathName] = put_or_get_file(handles,{'*.dat', 'X,Y (*.dat)';'*.*', 'All Files (*.*)'},'X,Y (ascii)','put', '.dat');
	if isequal(FileName,0),		return,		end     % User gave up	
    hM = findobj(handles.figure1,'Type','Line','tag','marker');
	x = get(hM,'XData');		y = get(hM,'YData');
	if (size(handles.data,2) == 2)			% Simplest but possibly non-existing case. Input data was only x,y
		double2ascii([PathName FileName],[x(:) y(:)],'%f\t%f');
		return
	end
	% Geog type data. Here we want also to save the distance along line
	ind = zeros(1,numel(x));
	for (k = 1:numel(x))		% Find indices of the points in the handles.data array
		ind(k) = find((handles.data(:,3) - y(k)) == 0);
	end
	ind = sort(ind);
	x  = handles.data(ind,1);
	y  = handles.data(ind,2);
	z  = handles.data(ind,3);
	r0 = get_distances([handles.data(1,1) x(1)], [handles.data(1,2) y(1)], handles.geog, handles.measureUnit, handles.ellipsoide);
	r  = get_distances(x, y, handles.geog, handles.measureUnit, handles.ellipsoide);	% This starts counting dist at x(1)
	% add r0 so distances are from start of profile
	double2ascii([PathName FileName], [x(:) y(:) r(:)+r0(2), z(:), ind(:)], '%f\t%f\t%f\t%f\t%d');

% ----------------------------------------------------------------------------------------------------
function Ctrl_v_CB(hObject, handles)
% Paste a line whose handle is stored in root's appdata
% For now only the x,y is fetch from stored line handle, but we should deal also with the case of a lon,lat,z line
	h = getappdata(0, 'CtrlCHandEcran');	% Get what's in this root's appdata
	if (isempty(h) || ~ishandle(h(1))),		return,		end
	x = get(h, 'xdata');		y = get(h, 'ydata');
	rmappdata(0, 'CtrlCHandEcran')
	ecran('add', x(:), y(:))

% ----------------------------------------------------------------------------------------------------
function extensional_CB(hObject, handles)
% Hide some buttons and put this one in a checked stat that will be used to decide if FitLines are plotted in Mir fig
	if (strcmp(get(hObject,'checked'),'off'))
		set(hObject,'checked', 'on')
		set(handles.Heaves, 'Vis', 'on')
		set(findobj(handles.figure1, 'Tag', 'isocs_but'), 'Vis', 'off')
		set(findobj(handles.figure1, 'Tag', 'rectang_but'), 'Vis', 'off')
		set(findobj(handles.figure1, 'Tag', 'pick_but'), 'Vis', 'off')
	end

% ----------------------------------------------------------------------------------------------------
function plotHeaves_CB(hObject, handles)
% Plot the cumulated heaves as function of distance along line
	[r, f_x] = commonHeaves(handles);
	if (numel(r) < 2),	return,		end		% We have a limitation when plotting single points
	heave = cumsum(abs(f_x(:,2) - f_x(:,1)));
	ecran(r, heave, 'Cumulated heaves', {'LineStyle','none', 'Marker','*'})

% ----------------------------------------------------------------------------------------------------
function plotExx_CB(hObject, handles)
% Plot the Exx estimate
	[r, f_x] = commonHeaves(handles);
	if (numel(r) < 3),	return,		end		% We have a limitation when plotting single points. 3 because its a difference
	dist_mean = diff((f_x(:,2) + f_x(:,1)) / 2);		% Distances between mean fault positions
	exx = (f_x(2:end,2) - f_x(2:end,1)) ./ dist_mean;
	ecran(r(2:end), exx, 'Exx', {'LineStyle','none', 'Marker','*'})

% ----------------------------------------------------------------------------------------------------
function saveHeaves_CB(hObject, handles)
% Save the fault picks info that can be used to calculate the Heaves, Exx, etc...
	[r, f_x, f_y, x1, y1, x2, y2] = commonHeaves(handles);
	if (isempty(r)),	return,		end
	[FileName,PathName] = put_or_get_file(handles,{'*.dat', 'X,Y (*.dat)';'*.*', 'All Files (*.*)'},'X,Y (ascii)','put', '.dat');
	if isequal(FileName,0),		return,		end     % User gave up
	fmt{1} = sprintf('# Lon_x1    Lat_y1    Lon_x2    Lat_y2    f_x1    f_x2    f_z1    f_z2\n>HEAVES');
	fmt{2} = '%g';
	double2ascii([PathName FileName],[x1 y1 x2 y2 f_x f_y], fmt);

% ----------------------------------------------------------------------------------------------------
function [r, f_x, f_y, x1, y1, x2, y2] = commonHeaves(handles, opt)
% OPT, optional arg with the handle of a specific fitLine (fault). If not provided we fish all FitLines
% R     -> distance along line since the first fault pick
% F_X   -> [Xi Xf] x distance along line of the begin and end of a fault pick (diff(F_X) == HEAVE)
% F_Y   -> [Yi Yf] z heights of theu base and top of fault pick (diff(F_Y) == Fault vert offset)
% X1,Y1 -> coordinates of the fault start (at its base)
% X2,Y2 -> coordinates of the fault end (at its top)

	if (nargin == 1)
		hFL = findobj(handles.axes1,'Type','Line','tag','FitLine');
	else
		hFL = opt;
	end
	ud = get(hFL, 'UserData');
	if (isempty(ud))
		r = [];	 f_x = [];	f_y = [];	x1 = [];	y1 = [];	x2 = [];	y2 = [];
		return
	end
	if (isa(ud, 'cell'))
		ud = cat(1, ud{:});
	end
	x1 = ud(:,4);
	[x1,ind] = sort(x1);
	ud = ud(ind,:);
	x2 = ud(:,5);

	% Need to find the y's matching x that do not necessarily fall on the profile line.
	ind1 = zeros(1,numel(x1));		ind2 = zeros(1,numel(x1));
	for (k = 1:numel(x1))			% Find indices of the points in the handles.data array
		[mi, ind1(k)] = min(abs(handles.dist - x1(k)));
		[mi, ind2(k)] = min(abs(handles.dist - x2(k)));
	end

	x1 = handles.data(ind1,1);	y1 = handles.data(ind1,2);
	x2 = handles.data(ind2,1);	y2 = handles.data(ind2,2);
	r = 0;
	if (numel(hFL) > 1)
		r = get_distances(x1, y1, handles.geog, handles.measureUnit, handles.ellipsoide);	% This starts counting dist at x(1)
	end
	f_x = ud(:,4:5);			% ...
	f_y = [ud(:,4) .* ud(:,1) + ud(:,2) ud(:,5) .* ud(:,1) + ud(:,2)];

% ----------------------------------------------------------------------------------------------------
function FileSaveSession_CB(hObject, handles)
% Save info necessary to reconstruct present figure in a .mat file (many cases will likely fail)

	if (isempty(handles.fname_session))
		pname = '.mat';
	else
		pname = handles.fname_session;		% Propose the original name
	end

	str1 = {'*.mat;*.MAT', 'Data files (*.mat,*.MAT)'};
	[FileName,PathName] = put_or_get_file(handles, str1, 'Select session file name', 'put', pname);
	if isequal(FileName,0),		return,		end
	fname = [PathName FileName];

	haveText = false;	havePline = false;

	ALLtextHand = findobj(get(handles.axes1,'Child'),'Type','text');
	nO = numel(ALLtextHand);
	Texto = struct('str',cell(1,nO), 'pos',cell(1,nO), 'angle',cell(1,nO), 'color',cell(1,nO), ...
		'FontSize',cell(1,nO), 'HorizontalAlignment',cell(1,nO), 'VerticalAlignment',cell(1,nO));
	for (i = 1:nO)
		Texto(i).str = get(ALLtextHand(i),'String');
		if (isempty(Texto(i).str)),  continue,	end
		Texto(i).pos = get(ALLtextHand(i),'Position');		Texto(i).FontAngle = get(ALLtextHand(i),'FontAngle');
		Texto(i).angle = get(ALLtextHand(i),'Rotation');	Texto(i).Tag = get(ALLtextHand(i),'Tag');
		Texto(i).color = get(ALLtextHand(i),'color');		Texto(i).FontName = get(ALLtextHand(i),'FontName');
		Texto(i).FontSize = get(ALLtextHand(i),'FontSize');	Texto(i).FontWeight = get(ALLtextHand(i),'FontWeight');
		Texto(i).HorizontalAlignment = get(ALLtextHand(i),'HorizontalAlignment');
		Texto(i).VerticalAlignment = get(ALLtextHand(i),'VerticalAlignment');
		haveText = true;
	end

    hFL = findobj(handles.axes1,'Type','Line','tag','FitLine');
	FitLine = [];		xFact = 1;
	if (~isempty(hFL))
		FitLine = get(hFL, 'UserData');
		xFact = getappdata(hFL(1), 'xFact');	% X scale factor (to account for geogs, km, Nm, etc)
	end

    hM = findobj(handles.axes1,'Type','Line','tag','marker');
	markers = [];
	if (~isempty(hM))
		x = get(hM,'XData');	y = get(hM,'YData');
		markers = [x(:) y(:)];
	end

	ALLlineHand = findobj(get(handles.axes1,'Child'),'Type','line');
	ALLlineHand = setxor(ALLlineHand, hM);		% Those are processed, so remove them from handles list
	ALLlineHand = setxor(ALLlineHand, hFL);

	Pline = struct('x','double');				% Just to shut up MLint
	m = 1;
	for (i = 1:numel(ALLlineHand))
		tag = get(ALLlineHand(i),'Tag');
		if (isempty(tag)),		continue,	end	% MAIN LINE. SHOULD CHECK FOR A PRTICULAR TAG INSTEAD
		xx = get(ALLlineHand(i),'XData');		yy = get(ALLlineHand(i),'YData');
		Pline(m).x = xx(:);			Pline(m).y = yy(:);
		Pline(m).LineWidth = get(ALLlineHand(i),'LineWidth');
		Pline(m).LineStyle = get(ALLlineHand(i),'LineStyle');
		Pline(m).color = get(ALLlineHand(i),'color');
		Pline(m).tag = tag;
		Marker = get(ALLlineHand(i),'Marker');
		if (Marker(1) ~= 'n')		% Not 'none' so something.
			Pline(m).Marker = Marker;
			Pline(m).Size = get(ALLlineHand(i),'MarkerSize');
			Pline(m).FillColor = get(ALLlineHand(i),'MarkerFaceColor');
			Pline(m).EdgeColor = get(ALLlineHand(i),'MarkerEdgeColor');
		end
		if (isappdata(ALLlineHand(i),'LineInfo'))
			Pline(m).LineInfo = getappdata(ALLlineHand(i),'LineInfo');
		end
		% Save all appdatas which will cause that the above two will potentially be repeated
		app = getappdata(ALLlineHand(i));
		ud = get(ALLlineHand(i), 'UserData');
		if (~isempty(ud)),	app.UserData = ud;		end
		if (~isempty(fieldnames(app)))
			if (isfield(app, 'polygon_data'))	% Remove this because it will be restored by ui_edit_polygon()
				app = rmfield(app, 'polygon_data');
			end
			if (~isempty(fieldnames(app))),		Pline(m).appd = app;	end
		end
		m = m + 1;	havePline = true;
	end
	if (m == 1),	Pline = [];		end			% Initiated but not used.

	hMirFig = [];
	if (~isempty(handles.handMir)),		hMirFig = handles.handMir.figure1;	end
	
	geog = handles.geog;
	ellipsoide    = handles.ellipsoide;
	measureUnit   = handles.measureUnit;
	offset_coords = handles.offset_coords;
	offset_axes   = handles.offset_axes;

	x = handles.data(:,1);		y = handles.data(:,2);		z = handles.data(:,3);		dist = handles.dist;
	save(fname, 'x', 'y', 'z', 'dist', 'xFact', 'markers', 'FitLine', 'hMirFig', 'ellipsoide', 'geog', ...
		'measureUnit', 'havePline','Pline', 'haveText','Texto', 'offset_coords', 'offset_axes', '-v6')
	% Trick to shut up stupid MLint warnings
	if (0 && hMirFig && FitLine && markers && x && y && z && dist && xFact && geog && ellipsoide && measureUnit), end
	if (0 && haveText && havePline && Pline && offset_axes && offset_coords), end

% ----------------------------------------------------------------------------------------------------
function FileOpenSession_CB(hObj, handles, fname)
% Open the session file and try to recreate as possible the status at time of session creation
% When the session was open via Mirone (e.g. with a drag-n-drop) HANDLES is the handle of a temporary
% (auxiliary) ecran Fig that will be deleted after this function executes.

	if (nargin == 2)
		if (isfield(handles, 'session_name'))
			FileName = handles.session_name;	PathName = [];
		else
			str1 = {'*.mat;*.MAT', 'Data files (*.mat,*.MAT)'};
			[FileName,PathName] = put_or_get_file(handles,str1,'Select session file name','get');
			if isequal(FileName,0),		return,		end
		end
	else
		FileName = fname;	PathName = [];
	end
	fname = [PathName FileName];

	s = load(fname);
	if (ishandle(s.hMirFig))		% OK, we still have a living original Parent Mirone figure
		h = ecran(guidata(s.hMirFig), s.x, s.y, s.z, fname);
	else							% Parent Mirone is gone, do a minimalist thing
		lix = struct('DefineEllipsoide', s.ellipsoide, 'geog', s.geog, 'DefineMeasureUnit',s.measureUnit);
		h = ecran(lix, s.x, s.y, s.z, fname);
	end

	handNew = guidata(h);
	handNew.fname_session = fname;	% Store session's name to propose it if user wants to edit and save again
	guidata(handNew.figure1, handNew)

	if (~isempty(s.markers))		% The red Markers
		for (k = 1:size(s.markers,1))
			line('XData', s.markers(k,1), 'YData', s.markers(k,2), 'Parent', handNew.axes1, 'LineStyle', 'none', ...
				'Marker','s', 'MarkerFaceColor','r', 'MarkerSize',5, 'Tag','marker')
		end
	end

	if (s.haveText)					% case of text strings
		try		s.Texto;			% Compatibility issue (Use a try because of compiler bugs)
		catch
			% Do it this way because compiled version canot tel 'Text' from 'text'
			t = load(fname,'Text');	s.Texto = t.Text;
		end
		for (i = 1:length(s.Texto))
			if (isempty(s.Texto(i).str)),		continue,	end
			h_text = text(s.Texto(i).pos(1), s.Texto(i).pos(2), s.Texto(i).pos(3), s.Texto(i).str,...
				'Parent',handNew.axes1, 'Rotation',s.Texto(i).angle,...
				'FontAngle',s.Texto(i).FontAngle, 'Tag',s.Texto(i).Tag, 'FontWeight',s.Texto(i).FontWeight,...
				'color',s.Texto(i).color, 'FontName',s.Texto(i).FontName, 'FontSize',s.Texto(i).FontSize);
			if (isfield(s.Texto(i),'VerticalAlignment')),	set(h_text,'VerticalAlignment',s.Texto(i).VerticalAlignment),		end
			if (isfield(s.Texto(i),'HorizontalAlignment')),	set(h_text,'HorizontalAlignment',s.Texto(i).HorizontalAlignment),	end
			draw_funs(h_text,'DrawText')		% Set texts's uicontextmenu
		end
	end

	if (s.havePline)					% case of polylines
		for (i = 1:length(s.Pline))
			h_line = line('Xdata',s.Pline(i).x,'Ydata',s.Pline(i).y,'Parent',handNew.axes1,'LineWidth',s.Pline(i).LineWidth,...
				'color',s.Pline(i).color,'Tag',s.Pline(i).tag, 'LineStyle',s.Pline(i).LineStyle);
			if (isfield(s.Pline(i),'Marker') && ~isempty(s.Pline(i).Marker))% New in 21-9-2011
				set(h_line, 'Marker', s.Pline(i).Marker, 'MarkerSize',s.Pline(i).Size, ...
					'MarkerFaceColor',s.Pline(i).FillColor, 'MarkerEdgeColor',s.Pline(i).EdgeColor)
			end		
			if (isfield(s.Pline(i),'appd') && ~isempty(s.Pline(i).appd))	% Need the isfield test for backward compat
				fdnames = fieldnames(s.Pline(i).appd);
				for (fd = 1:numel(fdnames))
					if (strcmp(fdnames{fd}, 'UserData'))		% This is a UserData stored in appdata
						set(h_line, 'UserData', s.Pline(i).appd.(fdnames{fd}))
					else
						setappdata(h_line, fdnames{fd}, s.Pline(i).appd.(fdnames{fd}))
					end
				end
			end
			if (isfield(s.Pline(i),'LineInfo') && ~isempty(s.Pline(i).LineInfo))	% Should not pass here
				setappdata(h_line,'LineInfo',s.Pline(i).LineInfo)
				set(h_line,'UserData',1)
				draw_funs(h_line,'isochron',{s.Pline(i).LineInfo})
			else
				draw_funs([], 'set_line_uicontext_XY', h_line)	% Set lines's uicontextmenu
			end
		end
	end

	if (~isempty(s.FitLine))		% The local fit lines
		xFact = 1;
		if (~isa(s.FitLine, 'cell')),	s.FitLine = {s.FitLine};	end
		for (k = 1:numel(s.FitLine))
			mb_e_slp = s.FitLine{k};
			h = line('XData', mb_e_slp(4:5), 'YData', (mb_e_slp(4:5) * mb_e_slp(1) + mb_e_slp(2)), ...
				'Parent', handNew.axes1, 'LineWidth',2, 'Tag', 'FitLine', 'UserData', mb_e_slp);

			cmenuHand = uicontextmenu('Parent',handNew.figure1);
			set(h, 'UIContextMenu', cmenuHand);
			uimenu(cmenuHand, 'Label', 'Slope (atan(a0)), m  &  Intercept ');
			uimenu(cmenuHand, 'Label', sprintf('%.2f     %.3f   %.9g', mb_e_slp(3), mb_e_slp(1), mb_e_slp(2)));
			uimenu(cmenuHand, 'Label', 'Recomp Slope/Intercept', 'Callback', {@recompSI,h, xFact, false}, 'Sep', 'on');
			uimenu(cmenuHand, 'Label', 'Delete this line', 'Callback', 'delete(gco)', 'Sep', 'on');
			ui_edit_polygon(h)
		end
		extensional_CB(handNew.extensional, handNew)
	end

	if (~isequal(s.offset_coords, [0 0]))		% We have an origin shift, apply it now (It fishes and updated handles)
		shift_orig([], [], s.offset_axes, handNew.hLine, s.offset_coords(1), s.offset_coords(2), 'nochilds')
	end

% --------------------------------------------------------------------
function AnalysisFFT_AmpSpectrum_CB(hObject, handles)
	if (isempty(handles.hLine)),	return,		end
	[x, y] = get_inside_rect(handles);
	Fs = 1 / (x(2) - x(1));			% Sampling frequency
	Fn = Fs/2;						% Nyquist frequency
	NFFT = 2.^(ceil(log(length(y))/log(2)));	% Next highest power of 2 greater than or equal to length(x)
	FFTX = fft(y,NFFT);							% Take fft, padding with zeros, length(FFTX)==NFFT
	NumUniquePts = ceil((NFFT+1)/2);
	FFTX = FFTX(1:NumUniquePts);				% fft is symmetric, throw away second half
	MX = abs(FFTX);								% Take magnitude of X
	% Multiply by 2 to take into account the fact that we threw out second half of FFTX above
	MX = MX*2;				MX(1) = MX(1)/2;	% Account for endpoint uniqueness
	MX(length(MX)) = MX(length(MX))/2;			% We know NFFT is even
	% Scale the FFT so that it is not a function of the length of x.
	xIsDatenum = getappdata(handles.axes1,'xIsDatenum');
	fLabel = 'Frequency (1/x_unit)';
	if (~isempty(xIsDatenum))
		Fn = Fn / (24 * 60);		fLabel = 'Frequency (1/min)';
	end
	MX = MX/length(x);			f = (0:NumUniquePts-1)*2*Fn/NFFT;
	ecran('reuse',f,MX,[],'Amplitude Spectrum',fLabel,[],'Amplitude Spectrum','semilogy')

% --------------------------------------------------------------------
function AnalysisFFT_PSD_CB(hObject, handles)
	if (isempty(handles.hLine)),	return,		end
	[x, y] = get_inside_rect(handles);
	Fs = 1 / (x(2) - x(1));		% Sampling frequency
	label = get(hObject,'Label');
	if (strcmp(label(1:3), 'PSD'))		% No mistake. this is actually the Welch method
		[Pxx,w] = welch(y, Fs);
	else
		[Pxx,w] = psd(y, Fs);
	end
	%[Pxx,w] = pmtm(y,[]);
	xIsDatenum = getappdata(handles.axes1,'xIsDatenum');
	fLabel = 'Frequency (1/x_unit)';
	if (~isempty(xIsDatenum))
		w = w / (24 * 60);		fLabel = 'Frequency (1/min)';
		%w = w /(2*pi) * Fs;
	end
	% We want to guarantee that the result is an integer if X is a negative power of 10.
	% To do so, we force some rounding of precision by adding 300-300.
	Pxx = (10.*log10(Pxx)+300)-300;    % Compute db
	ecran('reuse',w,Pxx,[],'Power Spectrum',fLabel,'Power Spectral Density (dB/...)','Periodogram PSD Estimate')

% --------------------------------------------------------------------
function [x, y] = get_inside_rect(handles)
% Gets the (x,y) data from the plot line and checks if a BB rectangle exists.
% If yes, clips data inside rectangle.
	if (isempty(handles.hLine))			% Happens when we created an histogram from "outside". E.g. in hist_seis.m
		hP = findobj(handles.axes1, 'Tag', 'Histogram');
		if (~isempty(hP))
			x = get(hP,'XData');		y = get(hP,'YData');
		else
			errordlg('Neither a line nor an histogram was found.', 'Error')
		end
	else
		x = get(handles.hLine(1),'XData');		y = get(handles.hLine(1),'YData');
	end
	if (~isempty(handles.hRect) && ishandle(handles.hRect))		% Find the points inside rectangle
		xRect = get(handles.hRect, 'XData');
		id = find(x >= xRect(1) & x <= xRect(4));
		if (isempty(id)),	return,		end		% Nothing inside rect
		x = x(id);			y = y(id);
	end

% --------------------------------------------------------------------
function AnalysisAutocorr_CB(hObject, handles)
	if (isempty(handles.hLine)),	return,		end
	[x, y] = get_inside_rect(handles);
	c = autocorr(y);						n = length(y);
	ecran('reuse',x,c(n:end),[],'Normalized Autocorrelation','Lag in user X units')

% --------------------------------------------------------------------
function AnalysisRemoveMean_CB(hObject, handles)
	if (isempty(handles.hLine)),	return,		end
	[x, y] = get_inside_rect(handles);
	recall_me(handles, x, y-mean(y), 'Mean Removed')		% New Fig

% --------------------------------------------------------------------
function AnalysisRemoveTrend_CB(hObject, handles)
	if (isempty(handles.hLine)),	return,		end
	[x, y] = get_inside_rect(handles);
	p = polyfit(x,y,1);		y_fit = polyval(p,x);
	recall_me(handles, x, y-y_fit, 'Trend Removed')		% New Fig

% --------------------------------------------------------------------
function AnalysisFitPoly_CB(hObject, handles)
	if (isempty(handles.hLine)),	return,		end
	xx = get(handles.hLine(1),'XData');		yy = get(handles.hLine(1),'YData');
	ind = isnan(yy);
	if (any(ind))
		xx(ind) = [];		yy(ind) = [];
	end
	handles.polyFig = ecran_trend1d(handles.axes1, [xx(:) yy(:)]);
	guidata(handles.figure1, handles)

% --------------------------------------------------------------------
function AnalysisSmoothSpline_CB(hObject, handles)
	if (isempty(handles.hLine)),	return,		end
	xx = get(handles.hLine(1),'XData');		yy = get(handles.hLine(1),'YData');
	[pp,p] = spl_fun('csaps',xx,yy);		% This is just to get csaps's p estimate
	y = spl_fun('csaps',xx,yy,p,xx);
	hold on;	h = plot(xx,y);		hold off

	smoothing_param(p, [xx(1) xx(2)-xx(1) xx(end)], handles.figure1, handles.axes1, handles.hLine, h);
	guidata(hObject, handles);

% --------------------------------------------------------------------
function AnalysisFilter_CB(hObject, handles, hLine)
	if (nargin == 2)			% Called from the Analysis menu
		if (isempty(handles.hLine)),	return,		end
		filter1d(handles.hLine)
	else						% Called from uictx menu (function handle call)
		filter1d(hLine)			% hLine is the handle of currently selected line
	end

% --------------------------------------------------------------------
function Analysis1derivative_CB(hObject, handles)
	if (isempty(handles.hLine)),	return,		end
	[xx, yy] = get_inside_rect(handles);
	%pp = spl_fun('csaps',xx,yy,1);		% Use 1 for not smoothing, just interpolate
	%v = spl_fun('ppual',pp,xx,'l','first');
	v = diffCenterVar(xx, yy);
	recall_me(handles, xx, v, 'First derivative')		% New Fig

% --------------------------------------------------------------------
function Analysis2derivative_CB(hObject, handles)
	if (isempty(handles.hLine)),	return,		end
	[xx, yy] = get_inside_rect(handles);
	[v, a] = diffCenterVar(xx, yy);
	recall_me(handles, xx, a, 'Second derivative')		% New Fig

% --------------------------------------------------------------------
function AnalysisSVP_CB(hObject, handles)
% Compute the SVP of this ARGO data
% Code from FEX:35916 Chad Greene (BSD license)
% adapted from from UNESCO (1983): Algorithms for computation of fundamental 
% properties of seawater. UNESCO technical papers in marine science 44:1-55.
% Employs CHEN AND MILLERO 1977, JASA, 62, 1129-1135

	pt = double(getappdata(handles.figure1, 'location'));		% [lon lat]
	T = double(getappdata(handles.figure1, 'Temp'));
	S = double(getappdata(handles.figure1, 'Sal'));
	P = double(getappdata(handles.figure1, 'Pressure')) / 10;	% Pressure was stored in decibars

	SR = sqrt(abs(S));
	% S^2 TERM
	D = 1.727e-3 - 7.9836e-6 * P;
	% S^3/2 TERM
	B1 =  7.3637e-5 + 1.7945e-7 * T;
	B0 = -1.922e-2  - 4.42e-5   * T;
	B  = B0 + B1 .* P;
	% S^1 TERM
	A3 = (-3.389e-13    .* T + 6.649e-12)  .* T + 1.100e-10;
	A2 = ((7.988e-12    .* T - 1.6002e-10) .* T + 9.1041e-9) .* T - 3.9064e-7;
	A1 = (((-2.0122e-10 .* T + 1.0507e-8)  .* T - 6.4885e-8) .* T - 1.2580e-5) .* T + 9.4742e-5;
	A0 = (((-3.21e-8    .* T + 2.006e-6)   .* T + 7.164e-5)  .* T - 1.262e-2)  .* T + 1.389;
	A  = ((A3.* P + A2) .*P + A1) .* P + A0;
	% S^0 TERM
	C3 = (-2.3643e-12   .* T + 3.8504e-10) .* T - 9.7729e-9;
	C2 = (((1.0405e-12  .* T - 2.5335e-10) .* T + 2.5974e-8) .* T - 1.7107e-6)  .* T + 3.1260e-5;
	C1 = (((-6.1185e-10 .* T + 1.3621e-7)  .* T - 8.1788e-6) .* T + 6.8982e-4)  .* T + 0.153563;
	C0 = ((((3.1464e-9  .* T - 1.47800e-6) .* T + 3.3420e-4) .* T - 5.80852e-2) .* T + 5.03711) .* T + 1402.388;
	C  = ((C3 .* P + C2) .* P + C1) .* P + C0;
	
	SVP = C + (A + B .* SR + D .* S) .* S;

	z = get_z_from_p(P*10, pt(2));		% Here pressure is expected in dbars
	s.figSize = [350 500];
	hFig = ecran(SVP, z, {s});
	delete(findobj(hFig, 'Label','Misc')),		delete(findobj(hFig, 'Label','Analysis'))
	delete(findobj(hFig, 'Tag','isocs_but')),	delete(findobj(hFig, 'Tag','rectang_but')),	delete(findobj(hFig, 'Tag','DynSlope'))
	hAx = findobj(hFig, 'Type', 'axes', 'Tag', 'axes1');
 	set(get(hAx, 'XLabel'), 'Str','Sound speed (m/s)'),		set(get(hAx, 'YLabel'), 'Str','Depths (m)')
	set(hFig, 'Name', 'SVP diagram')

% --------------------------------------------------------------------
function z = get_z_from_p(p, lat)
% Stripped down from the function with same name in the TEOS-10 Toolbox
% INPUT:
%  p    =  sea pressure                                            [ dbar ]
%          ( i.e. absolute pressure - 10.1325 dbar )
%  lat  =  latitude in decimal degrees north                [ -90 ... +90 ]

	gamma = 2.26e-7;	% If the graviational acceleration were to be regarded as 
						% being depth-independent, which is often the case in 
						% ocean models, then gamma would be set to be zero here,
						% and the code below works perfectly well.
	sinlat = sin(lat*pi/180);
	sin2 = sinlat .* sinlat;
	B = 9.780327 * (1 + (5.2792e-3 + (2.32e-5*sin2)) .* sin2); 
	A = -0.5 * gamma * B;
	C = gsw_enthalpy_SSO_0(p);
	z = -2 * C ./ (B + sqrt(B.*B - 4 * A .* C));

% --------------------------------------------------------------------
function enthalpy_SSO_0 = gsw_enthalpy_SSO_0(p)
% From the function with same name in the TEOS-10 Toolbox
	z = p.*1e-4;
	h006 = -2.1078768810e-9;	h007 =  2.8019291329e-10; 

	dynamic_enthalpy_SSO_0_p = z.*(9.726613854843870e-4 + z.*(-2.252956605630465e-5 ...
		+ z.*(2.376909655387404e-6 + z.*(-1.664294869986011e-7 ...
		+ z.*(-5.988108894465758e-9 + z.*(h006 + h007.*z))))));
	enthalpy_SSO_0 = dynamic_enthalpy_SSO_0_p * 1e8;     %Note. 1e8 = db2Pa*1e4;

% --------------------------------------------------------------------
% function AnalysisSegmentation_CB(hObject, handles)
% 	if (isempty(handles.hLine)),	return,		end
% 	[xx, yy] = get_inside_rect(handles);
% 	xx = xx(:);		yy = yy(:);
% 	DP_tol = 5;
% 	B = cvlib_mex('dp',[xx yy],DP_tol,'GEOG');
% 	XI = B(:,1);
% 	YI = lsq_lut_piecewise(xx, yy, XI);
% 	figure; plot(xx,yy,'.',XI,YI,'+-')

% --------------------------------------------------------------------
function recall_me(handles, x, y_new, title)
% Create another Ecran fig but try to maintain all features of the original one (e.g, the linking button)
	if (~isempty(handles.handMir))
		ecran(handles.handMir, handles.data(:,1), handles.data(:,2), y_new(:), title)
	elseif (size(handles.data,2) == 3)
		stru = struct('DefineEllipsoide', handles.ellipsoide, 'geog', handles.geog, ...
		              'DefineMeasureUnit',handles.measureUnit);
		ecran(stru, handles.data(:,1), handles.data(:,2), y_new(:), title)
	else
		ecran('reuse', x, y_new(:), [], title)
	end

% --------------------------------------------------------------------
function edit_startAge_CB(hObject, handles)
	xx = str2double(get(hObject,'String'));
	if (isnan(xx))
		set(hObject,'String','')
	elseif (xx < 0)
		xx = 0;
		set(hObject,'String',xx)
	end
	handles.ageStart = xx;
	guidata(handles.figure1, handles)

% --------------------------------------------------------------------
function edit_ageEnd_CB(hObject, handles)
	xx = str2double(get(hObject,'String'));
	if (isnan(xx)),		set(hObject,'String',''),	end
	handles.ageEnd = xx;
	guidata(handles.figure1, handles)

% --------------------------------------------------------------------
function push_magBar_CB(hObject, handles)
% Create the Mag Bar in axes2.
% If HANDLES has the optional field 'stretchMagBar', the bars position will be
% stretch/shrunk (depending whether the factor is > or < than 1) to simulate the
% effect of oblique profile and/or oblique spreading

	if (isnan(handles.ageStart) || isnan(handles.ageEnd))
		errordlg('Take a second look to what you are asking for. Wrong ages','Error'),		return
	end

	% First delete the Coordinates status bar because it shares the same space as that of the Mag Bar
	pixval_stsbar('exit')

	set(handles.axes2, 'Vis', 'on', 'YTick',[])

	reverse_XDir = false;		% If first age > last age, we'll revert the sense of the X axis
	if (handles.ageStart >= handles.ageEnd)
		reverse_XDir = true;
		tmp = handles.ageStart;		handles.ageStart = handles.ageEnd;		handles.ageEnd = tmp;
		set(handles.axes2,'XDir','reverse')
	end

	fid = fopen([handles.d_path 'Cande_Kent_95.dat'],'r');
	todos = fread(fid,'*char');
	[chron, age_start, age_end, age_txt] = strread(todos,'%s %f %f %s');
	fclose(fid);    clear todos

	id_ini = (age_start >= handles.ageStart);		id_ini = find(id_ini);		id_ini = id_ini(1);
	id_fim = (age_start <= handles.ageEnd);			id_fim = find(~id_fim);		id_fim = id_fim(1) - 1;
	if (id_ini > 1),	agesLeftBak = [age_start(id_ini-1) age_end(id_ini-1)];	% We may need this to build a left clipped brick
	else,				agesLeftBak = [age_start(1) age_end(1)];	% To not error out further down
	end
	age_start = age_start(id_ini:id_fim);
	age_end = age_end(id_ini:id_fim);
	age_txt = age_txt(id_ini:id_fim);

	% Take care of end ages which certainly do not coincide with what was asked
	if (age_start(1) > handles.ageStart && handles.ageStart < agesLeftBak(2))	% We must create a clipped first brick
		age_start = [handles.ageStart; age_start];
		age_end = [agesLeftBak(2); age_end];
		age_txt = cat(1,{'a'}, age_txt(:));
	end
 	if (age_end(end) > handles.ageEnd)			% Clip the last brick
		age_end(end) = handles.ageEnd;
	end

	if (isfield(handles, 'stretchMagBar') && handles.stretchMagBar ~= 1)		
		% Need to stretch/shrink due to oblique profile and/or oblique spreading
		age_start = age_start * handles.stretchMagBar;
		age_end = age_end * handles.stretchMagBar;
	end

	x = [age_start'; age_end'];
	x = x(:);
	y = [zeros(numel(x),1); ones(numel(x),1)]; 
	x = [x; x(end:-1:1)];

	n_ages = numel(age_start);
	n2 = 2 * n_ages;
	c1 = (1:n2-1)';     c3 = n2*2 - c1;
	c2 = c3 + 1;        c4 = c1 + 1;
	faces = [c1 c2 c3 c4];

	cor = repmat([0 0 0; 1 1 1],n_ages-1,1);    cor = [cor; [0 0 0]];
	set(handles.axes2, 'xlim', [handles.ageStart handles.ageEnd])
	if (isempty(handles.hPatchMagBar))
		handles.hPatchMagBar = patch('Parent',handles.axes2,'Faces',faces,'Vertices',[x y],'FaceVertexCData',cor,'FaceColor','flat');
		set(handles.hPatchMagBar, 'Tag', 'MagBarCode', 'ButtonDownFcn', {@bdn_MagBar,handles.figure1})
	else
		set(handles.hPatchMagBar,'Faces',faces,'Vertices',[x y],'FaceVertexCData',cor)
	end
	set(handles.figure1,'renderer','Zbuffer')	% The patch command above set it to OpenGL, which is f... bugged

	% Get the index of anomalies that have names. We'll use them to plot those anomaly names
	ind = false(1,n_ages);
	for (i = 1:n_ages)
		if (~strcmp(age_txt(i),'a')),	ind(i) = true;		end
	end
	ages = age_start(ind);

	set(handles.figure1,'currentaxes',handles.axes1)	% Put it back as current axes
	% Since the two axes are touching, axes1 hides the XTickLabels of axes2.
	% So the trick is to plot what would have been axes2 XTickLabels as a text in axes1
	DX1 = diff(get(handles.axes1,'xlim'));
	y_lim = get(handles.axes1,'ylim');
	DX2 = handles.ageEnd - handles.ageStart;
	x_pos = (ages - handles.ageStart) * DX1 / DX2;
	ha = 'Left';
	if (reverse_XDir)
		x_pos = (age_end(end) - x(1)) * DX1 / DX2 - x_pos;
		ha = 'Right';
	end
	if (~isempty(handles.hTxtChrons))
		delete(handles.hTxtChrons)
	end
	handles.hTxtChrons = text(x_pos,repmat(y_lim(2),numel(x_pos),1),age_txt(ind),'Parent',handles.axes1, ...
			'VerticalAlignment','top', 'HorizontalAlignment', ha, 'Tag','chroneName');
	set(handles.axes2, 'XTick',[],'UserData',ages)		% We may want to use these from other places
	
	set(handles.push_syntheticRTP, 'Vis','on')			% Now this may be set to visible
	guidata(handles.figure1, handles)

% -----------------------------------------------------------------------------------------
function bdn_MagBar(obj,evt, hFig)
% ...
	handles = guidata(hFig);
	stype = get(handles.figure1,'selectiontype');
	if (~strcmp(stype,'open')),		return,		end

	% Create a pico marker
	p = get(handles.axes2,'currentpoint');		px = p(1,1);
	y = get(handles.axes2,'YLim');		xLim = get(handles.axes2,'XLim');
	yh = 0.8;					% Stick height (0.8 of axe's height)
	yv = yh / 2.5;				% Stick point height
	xw = diff(xLim) * 0.005;	% Stick half-width
	x = [px px-xw px-xw px+xw px+xw px];
	y = [y(1) yv y(1)+yh y(1)+yh yv y(1)];
	h = patch(x,y,'r');
	yLim = get(handles.axes1,'YLim');
	orig_u = get(handles.axes1, 'units');
	set(handles.axes1, 'units', 'normalized');
	x_in_1 = px / diff(xLim) * diff(get(handles.axes1,'XLim'));
	hLine = line('Parent',handles.axes1, 'XData', [x_in_1 x_in_1], 'YData', yLim);
	set(handles.axes1, 'units', orig_u);
	set(h, 'Tag', 'Picos', 'UserData',hLine, 'ButtonDownFcn',{@bdn_pico,hFig,h,xw})

function bdn_pico(obj,evt,hFig,h,xw)
	handles = guidata(hFig);
	stype = get(handles.figure1,'selectiontype');
	if strcmp(stype,'open')
		delete(get(h, 'UserData'))
		delete(h)
	else
		state = uisuspend_j(hFig);				% Remember initial figure state
		set(handles.figure1,'WindowButtonMotionFcn',{@wbm_pico,hFig, h, xw}, ...
			'WindowButtonUpFcn',{@wbu_pico,hFig, state});
	end

function wbm_pico(obj,evt, hFig, h, xw)
% On 'Pico' motion do this
	handles = guidata(hFig);
	p = get(handles.axes2,'currentpoint');		px = p(1,1);
	x = get(handles.axes2,'XLim');
	if (px < 0 || px > x(end)),		return,		end			% Don't get out of the Bar Code
	x = [px px-xw px-xw px+xw px+xw px];
	set(h,'XData',x)
	hLine = get(h, 'UserData');
	x_in_1 = px / diff(get(handles.axes2,'XLim')) * diff(get(handles.axes1,'XLim'));
	set(hLine, 'XData', [x_in_1 x_in_1])

function wbu_pico(obj,evt, hFig, state)
% When Up, restore Figur's previous state
	uirestore_j(state, 'nochildren');		% Restore the figure's initial state
% -----------------------------------------------------------------------------------------

% ---------------------------------------------------------------------
function push_syntheticRTP_CB(hObject, handles)
% Compute a synthetic profile RTPed

	switch handles.measureUnit(1)
		% scale_x is the scale factor that always give distances in km
		case 'n',		distSpeedFact = 1.852*1e-1;		scale_x = 1.852;	% Nautical miles
		case 'k',		distSpeedFact = 1e-1;			scale_x = 1;		% Kilometers
		case 'm',		distSpeedFact = 1e-4;			scale_x = 1e-3;		% Meters
	end
	speed =  2 * handles.dist(end) / (handles.ageEnd - handles.ageStart) * distSpeedFact;	% Full rate in cm / yr

	fdec = 0;		finc = 90;		spreaddir = [];
	dir_profile = azimuth_geo(handles.data(1,2), handles.data(1,1), handles.data(end,2), handles.data(end,1));
	batFile = [];		dxyp = [];		contamin = 1;		syntPar = handles.syntPar;
	handles.syntPar.ageStretch = 0;		% If needed, tt will expanded further down
	handles.syntPar.agePad = 1.5;		% Is overwriten by value in OPTcontrol. Probably too short for older isochrons

	% See if the case the OPTcontrol.txt file has relevant info for this run
	opt_file = [handles.home_dir filesep 'data' filesep 'OPTcontrol.txt'];
	if (exist(opt_file, 'file') == 2)
		fid = fopen(opt_file, 'r');
		c = (fread(fid,'*char'))';      fclose(fid);
		lines = strread(c,'%s','delimiter','\n');   clear c fid;
		m = numel(lines);		kk = 2;		% kk starts at 2 because first line in popup is empty
		for (k = 1:m)
			if (~strncmp(lines{k},'MIR_MAGPROF',7)),	continue,	end
			if (numel(lines{k}) <= 14),	continue,	end		% The minimum it takes to have a -? switch
			[t, r] = strtok(lines{k}(13:end));
			switch t
				case 'DEC',			fdec = str2double(r);
				case 'INC',			finc = str2double(r);
				case 'SPEED',		speed = str2double(r);
				case 'SPREADIR',	spreaddir = str2double(r);
				case 'CONTAMIN',	contamin = str2double(r);
				case 'BAT'			% Get file name of a grid with bathymetry that will be interpolated at track pos
					batFile = ddewhite(r);
					if (exist(batFile,'file') ~= 2)
						errordlg(['Bathymetry grid ' r ' does not exist. Ignoring bat request'],'Error')
						batFile = [];
					end
					
				case 'ISOC'			% The list of isochrons (by its age) that will be tentatively fit
					ind = strfind(r, '_');
					if (~isempty(ind))
						if (numel(ind) == 2)
							handles.syntPar.ageStretch(kk) = fix(str2double(r(ind(2)+1:end)));	% Used to expand/shrink in corr
							r(ind(2):end) = [];		% Wipe it out so the "...agePad(kk)" assignement works for any 'ind'
						else
							handles.syntPar.ageStretch(kk) = 0;
						end
						handles.syntPar.ageMarkers{kk} = r(1:ind(1)-1);
						handles.syntPar.agePad(kk) = str2double(r(ind(1)+1:end));
					else
						handles.syntPar.ageMarkers{kk} = r;
						handles.syntPar.agePad(kk) = 1.5;		% Default (and possibly too short for old isocs) value
					end
					kk = kk + 1;
			end
		end
		set(handles.popup_ageFit,'Vis','on','Str',handles.syntPar.ageMarkers)
		set(handles.edit_ageFit, 'Vis', 'off')		% We don't use this in this case.
		if (contamin <= 1 && contamin >= 0.5)
			set(handles.slider_filter,'Val', contamin)
		else
			contamin = 1;				% Case user screwed up
		end
		if (kk == 2)					% No MIR_MAGPROF info in OPTcontrol.txt but we need an not [] ageStretch field
			handles.syntPar.ageStretch = zeros(1,2);
		end
		syntPar = true;					% Signal that got Params from file
	end

	handles.syntPar.dec = fdec;
	handles.syntPar.inc = finc;
	handles.syntPar.speed = speed;
	handles.syntPar.dir_profile = dir_profile;
	if (~isempty(spreaddir))
		handles.syntPar.dir_spread = spreaddir;
	else
		handles.syntPar.dir_spread = dir_profile;
	end
	
	if (isempty(syntPar))				% First time use in this session and no OPTcontrol.txt info
		set(handles.edit_ageFit, 'Vis','on')
	end
	set([handles.push_ageFit handles.slider_filter], 'Vis','on')

	if (~isempty(batFile))				% Try to extract the bathym profile by grid interpolation
		if (isempty(handles.batTrack))	% Do grid interpolation only once
			[handles, X, Y, Z, head] = read_gmt_type_grids(handles, batFile);
			if (~isempty(Z))
				zz = abs(grdtrack_m(Z,head,handles.data(:,1:2),'-Z')) / 1000;	% Need Z in km
				if (all(zz == 0))
					warndlg('Bat grid used but profile is probably out of its limits. Ignoring bat grid track.','Warning')
				else
					dxyp = [handles.dist * scale_x handles.data(:,1:2) zz(:)];
					handles.batTrack = zz;
				end
			end
		end
	end

	if (handles.handMir.is_projected)		% In this case we wont expect to have a bathymetry profile
		proj = aux_funs('get_proj_string', handles.handMir.figure1, 'proj');
		[xy, msg] = proj2proj_pts([], handles.data(:,1:2), 'srcProj4', proj, 'dstProj4', '+proj=longlat');
		if (~isempty(msg))
			errordlg(msg, 'Error'),		return
		end
		rd = get_distances(xy(:,1), xy(:,2), 1, 'k', handles.ellipsoide);
		dxyp = [rd xy ones(size(handles.data,1),1)*2.5];
		if (handles.syntPar.speed > 25)		% Previous value was based on projected coords
			handles.syntPar.speed =  2 * rd(end) / (handles.ageEnd - handles.ageStart) * 0.1;
		end
		handles.syntPar.dir_profile = azimuth_geo(xy(1,2), xy(1,1), xy(end,2), xy(end,1));
		handles.syntPar.dir_spread  = handles.syntPar.dir_profile;
	else
		if (isempty(dxyp) && isempty(handles.batTrack))
			dxyp = [handles.dist * scale_x handles.data(:,1:2) ones(size(handles.data,1),1)*2.5];
		elseif (isempty(dxyp) && ~isempty(handles.batTrack))
			dxyp = [handles.dist * scale_x handles.data(:,1:2) handles.batTrack(:)];
		end
	end

	[anom, handles.age_line] = magmodel(handles.axes2, [handles.d_path 'Cande_Kent_95.dat'], dxyp, handles.syntPar.dec, ...
			handles.syntPar.inc, handles.syntPar.speed, handles.syntPar.dir_spread, handles.syntPar.dir_profile, 0, contamin);

	if (isempty(handles.hSynthetic))
		if (strncmp(get(handles.axes2,'XDir'),'normal', 3))
			handles.hSynthetic = line('XData', handles.dist, 'YData', anom, 'Parent', handles.axes1, 'Color', 'r');
		else
			handles.hSynthetic = line('XData', handles.dist(end:-1:1), 'YData', anom, 'Parent', handles.axes1, 'Color', 'r');
		end
		uistack_j(handles.hSynthetic, 'bottom')		% It's preferable to have it lower on stack than data profile
	else
		if (strncmp(get(handles.axes2,'XDir'),'normal', 3))
			set(handles.hSynthetic, 'XData', handles.dist, 'YData', anom)
		else
			set(handles.hSynthetic, 'XData', handles.dist(end:-1:1), 'YData', anom)
		end
	end
	
	guidata(handles.figure1, handles)

% ---------------------------------------------------------------------
function slider_filter_CB(hObject, handles)
% Filter the synthetic mag profile by using the conatmination factor
	contamin = get(hObject, 'Val');
	% Compute distance scale factor (magmodel wants dist in km)
	switch handles.measureUnit(1)
		case 'n',		scale_x = 1.852;	% Nautical miles
		case 'k',		scale_x = 1;		% Kilometers
		case 'm',		scale_x = 1e-3;		% Meters
	end

	if (~isempty(handles.batTrack))
		dxyp = [handles.dist * scale_x handles.data(:,1:2) handles.batTrack(:)];
	else
		dxyp = [handles.dist * scale_x handles.data(:,1:2)];
	end
	anom = magmodel(handles.axes2, [handles.d_path 'Cande_Kent_95.dat'], dxyp, handles.syntPar.dec, handles.syntPar.inc, ...
		handles.syntPar.speed, handles.syntPar.dir_spread, handles.syntPar.dir_profile, 0, contamin);
	set(handles.hSynthetic, 'YData', anom);

% ---------------------------------------------------------------------
function popup_ageFit_CB(hObject, handles)
% Put/update a marker on the synthetic line corresponding to the age of the slected popup value

	str = get(hObject,'str');		val = get(hObject,'Val');
	if (val == 1),		return,		end			% First entry is empty
	xx = str2double(str{val});					% The Isochron age at its center (or not, if user wants to invent)

	if (~isfield(handles,'hMarkerToGuess'))		% First time here. Start with an empty handle
		handles.hMarkerToGuess = [];
	elseif (~isempty(handles.hMarkerToGuess))	% A previous one exist. Delete it and reset to empty
		delete(handles.hMarkerToGuess);		handles.hMarkerToGuess = [];
	end

	[mimi,ind] = min(abs(handles.age_line - xx));
	x = get(handles.hSynthetic, 'XData');		y = get(handles.hSynthetic, 'YData');
	y_age_on_line = y(ind);						x_age_on_line = x(ind);
	if (isempty(handles.hAgeMarker))			% The Red Star
		handles.hAgeMarker = line('XData',x_age_on_line, 'YData',y_age_on_line, 'Parent',handles.axes1, ...
			'Marker','p','MarkerFaceColor','r','MarkerEdgeColor','k','MarkerSize',11);

		% Create a uimenu to allow users to point into an aproximate position of seeked correlation maximum
		cmenuHand = uicontextmenu('Parent',handles.figure1);
		set(handles.hAgeMarker, 'UIContextMenu', cmenuHand)
		uimenu(cmenuHand, 'Label', 'Guide me', 'Callback', @setFirstGuessForCorrelation);
	else
		set(handles.hAgeMarker, 'XData',x_age_on_line, 'YData',y_age_on_line)
	end
	set(handles.hAgeMarker,'UserData', ind)		% Store the index of the red star for later reference
	guidata(handles.figure1, handles)			% Sometimes this is not needed, but won't hurt either

% ---------------------------------------------------------------------
function edit_ageFit_CB(hObject, handles)
% Put/update a marker on the synthetic line corresponding to age entered here

	xx = abs(str2double(get(handles.edit_ageFit,'String')));
	if (isnan(xx)),		set(hObject,'Str',''),	return,		end

	if (~isfield(handles,'hMarkerToGuess'))		% First time here. Start with an empty handle
		handles.hMarkerToGuess = [];
	elseif (~isempty(handles.hMarkerToGuess))	% A previous one exist. Delete it and reset to empty
		delete(handles.hMarkerToGuess);		handles.hMarkerToGuess = [];
	end

	[mimi,ind] = min(abs(handles.age_line - xx));
	x = get(handles.hSynthetic, 'XData');		y = get(handles.hSynthetic, 'YData');
	y_age_on_line = y(ind);						x_age_on_line = x(ind);
	if (isempty(handles.hAgeMarker))
		handles.hAgeMarker = line('XData',x_age_on_line, 'YData',y_age_on_line, 'Parent',handles.axes1, ...
			'Marker','p','MarkerFaceColor','r','MarkerEdgeColor','k','MarkerSize',11);
		set(handles.hAgeMarker, 'UserData', ind)% Save the index of the point where the star lies.

		% Create a uimenu to allow users to point into an aproximate position of seeked correlation maximum
		cmenuHand = uicontextmenu('Parent',handles.figure1);
		set(handles.hAgeMarker, 'UIContextMenu', cmenuHand)
		uimenu(cmenuHand, 'Label', 'Guide me', 'Callback', @setFirstGuessForCorrelation);
	else
		set(handles.hAgeMarker, 'XData',x_age_on_line, 'YData',y_age_on_line)
	end
	set(handles.hAgeMarker,'UserData', ind)		% Store this index for later reference
	guidata(handles.figure1, handles)			% Sometimes this is not needed, but won't hurt either

% ---------------------------------------------------------------------
function setFirstGuessForCorrelation(obj, evt)
% First step in adding a marker on the mag anom line to guide the correlation with synthetic profile
	handles = guidata(obj);
	handles.state = uisuspend_j(handles.figure1);			% Remember initial figure state
	set(handles.figure1,'WindowButtonDownFcn',@add_firstGuesssMarker, 'pointer','crosshair')
	guidata(handles.figure1,handles)

function add_firstGuesssMarker(obj, evt)
% Do the actual work of adding the marker that will act as the first guess of the max corr position
	handles = guidata(obj);
	button = get(handles.figure1, 'SelectionType');
	if (strcmp(button,'normal'))		% Left click only
		% Get the clicked pt
		[pt_x, pt_y, x_off] = get_pointOnLine(handles.axes1, handles.hLine);
		if (isempty(handles.hMarkerToGuess))
			handles.hMarkerToGuess = line('Parent',handles.axes1, 'XData',pt_x, 'YData',pt_y, 'Marker','o', ...
				'MarkerFaceColor',[0 .6 0], 'MarkerEdgeColor','k','MarkerSize',7, 'Tag','GuessMarker', 'UserData',x_off);
			guidata(handles.figure1, handles)
		else
			set(handles.hMarkerToGuess,'XData',pt_x, 'YData',pt_y, 'UserData',x_off)
		end
	end
	uirestore_j(handles.state, 'nochildren');				% Restore the figure's initial state
% ---------------------------------------------------------------------

% ---------------------------------------------------------------------
function push_ageFit_CB(hObject, handles)
% Take the age entered in edit_ageFit, find that point in synthetic and
% find its best fit on the measured profile by correlation.
	if (strcmp(get(handles.popup_ageFit,'Vis'), 'on'))		% We have a group of ages (isocs) to choose (via OPTcontrol)
		str = get(handles.popup_ageFit,'str');		val = get(handles.popup_ageFit,'Val');
		if (val == 1),		return,		end			% First entry is empty
		xx = str2double(str{val});
		agePad = handles.syntPar.agePad(val);
		ageStretch = handles.syntPar.ageStretch(val);
	else											% Fit only one isoc whose age was set by the edit box
		xx = abs(str2double(get(handles.edit_ageFit,'String')));
		if (isnan(xx))
			errordlg('Pelease, fit what? Your anniversary? How many Ma?', 'error'),		return
		end
		agePad = handles.syntPar.agePad;
		ageStretch = 15;							% Default to use this stretch (15%).
	end

	x = get(handles.hSynthetic, 'XData')';			y = get(handles.hSynthetic, 'YData')';
	y_ano = get(handles.hLine,'YData');				y_ano = y_ano(:);
	if (strcmp(get(handles.axes2,'XDir'),'normal'))
		age_line = handles.age_line;
	else
		age_line = handles.age_line(end:-1:1);		% When profile was drawn from Old to New some of the vectors
		x = x(end:-1:1);							% are reversed (age for instance) which makes a bit of a mess
		y = y(end:-1:1);
	end

	% Get a chunk of synthetic data centered on age marker.
	[mimi,ind_a] = min(abs(age_line - (xx - agePad)));
	[mimi,ind_b] = min(abs(age_line - (xx + agePad)));
	ind_a = max(1, ind_a);		ind_b = min(numel(age_line), ind_b);	% Make sure we are not outside of limits
	if (~strncmp(get(handles.axes2,'XDir'),'normal', 3))
		t = ind_a;	ind_a = ind_b;	ind_b = t;
	end
	y = y(ind_a:ind_b);

	% --------------- See if we have a user help in the form of a first aproximate solution ------------------
	guess_shift = 0;
	hGuess = findobj(handles.axes1, 'type', 'line', 'Tag','GuessMarker');
	if (~isempty(hGuess))
		xGuess_ind = get(hGuess, 'UserData');		% Get the index of the Star (selected age) and circle (first guess)
		xStar_ind  = get(handles.hAgeMarker, 'UserData');
		guess_shift = xGuess_ind - xStar_ind;		% Distance shift introduced by the 'Guessed point'
		ind_a = ind_a + guess_shift;				% Move the fetching widow to the interval centered on 'FirstGuess'
		ind_b = ind_b + guess_shift;
		if (ind_a < 1 || ind_b > numel(x))
			errordlg('Can''t continue. Guess solution implies a data shortage of points at one of the limits.','Error')
			return
		end
	end
	% --------------------------------------------------------------------------------------------------------

	y_ano = y_ano(ind_a:ind_b);					% Get the corresponding chunk of the measured anomaly

	indNan = isnan(y_ano);
	if (any(indNan))				% Shit. Not good
		xx = x(ind_a:ind_b);
		y_ano(indNan) = interp1(xx(~indNan), y_ano(~indNan), xx(indNan), 'linear', 'extrap');
	end

	% Normalize and remove mean
	y_ano = (y_ano-min(y_ano)) / (max(y_ano)-min(y_ano));	y_ano = y_ano(:) - mean(y_ano);
	yn    = (y - min(y)) / (max(y)-min(y));					yn = yn(:) - mean(yn);		% Synthetic

	shift = sanitize_shift(yn, y_ano, ageStretch);		% <===== DO THE HEAVY BRILIANT WORK

	if ((ind_a+shift < 1) || (ind_b+shift > numel(x)))
		warndlg('Guess work by convolution failed (index out of bounds). Try increase the isochron pad limits','Warning')
		return
	end
	x = x(ind_a+shift:ind_b+shift);				% Get new abssissae after the result of the CORR fit

	% Create or update the line chunk that shows new pos after CORR fit
	if (isempty(handles.hLineChunk_fit))
		handles.hLineChunk_fit = line('XData',x, 'YData', y, 'Parent', handles.axes1, 'LineStyle', '--');
	else
		set(handles.hLineChunk_fit, 'XData',x, 'YData',y)
	end

	% Create or move the age marker as well (the vertical dashed line)
	ind_ageMarker = get(handles.hAgeMarker,'UserData') + guess_shift;
	if (~strncmp(get(handles.axes2,'XDir'),'normal', 3))	% The time axis is reversed (grows from right to left)
		ind_ageMarker = numel(age_line) - ind_ageMarker + 1;
	end
	delta_shift = ind_ageMarker - ind_a + 1;	% Age marker must be shifted by this after corr-fit
	xx = [x(delta_shift) x(delta_shift)];		yy = get(handles.axes1,'ylim');
	if (isempty(handles.hAgeLine_fit))
		handles.hAgeLine_fit = line('XData',xx, 'YData',yy, 'Parent',handles.axes1, 'LineStyle', '--');
		cmenuHand = uicontextmenu('Parent',handles.figure1);
		set(handles.hAgeLine_fit, 'UIContextMenu', cmenuHand)
		uimenu(cmenuHand, 'Label', 'Pin-point me', 'Callback', {@pinpointLine, handles.hAgeLine_fit});
		uistack_j(handles.hAgeLine_fit, 'bottom')	% To not partially hide the red star
	else
		set(handles.hAgeLine_fit, 'XData',xx, 'YData',yy)
	end
	guidata(handles.figure1, handles)

% --------------------------------------------------------------------------------------------------
function shift = sanitize_shift(y_synt, y_ano, percent)
% Find index of maximum correlation between the Y_SYNT & Y_ANO series
% That maximum is searched around +- 20% of Tau = 0. That is, only 40% of the
% possible lag space is scanned. We do this to avoid 'outlier maximums'
%
% Y_SYNT	Synthetic anomaly
% Y_ANO		Measured anomaly (same size as Y_SYNT)
% PERCENT	Percentage of expand/shrink. This value is applied from 1:PERCENT to deform
%			the Y_SYNT before doing the cross correlation. At the end retain max correlation
% SHIFT		Index of Y_SYNT at which we obtain the maximum correlation beteen Y_SYNT & Y_ANO

	if (percent == 0),		percent = 1;	end
	y_synt = y_synt(end:-1:1);		% Revert because we want CORR, not CONV, in the call to conv2
	n_pts = numel(y_synt);
	if (rem(n_pts, 2))				% n_pts is Odd
		x_half = ceil(n_pts / 2);		x = -(x_half-1):(x_half-1);
	else
		x_half = n_pts / 2;				x = -(x_half-1):x_half;
	end
	
	c = round(n_pts * 0.20);		% Find how many points are 20% of the profile full length
	bond = n_pts-c:n_pts+c;			% Vector about Tau = 0 where correlation will taken into account
									% That is, bond = Tau +- 20% of all possible lags

	mimi = zeros(1, percent);		ind_ = zeros(1, percent);		x = x(:);
	for (k = 1:percent)				% Expand the synthetic curve up to PERC percent
		xi = x * (1 - (k-1)*1e-2);
		yi = interp1(x, y_synt, xi);
		w = conv2(yi, y_ano, 'full');	% We use conv2 instead of conv ... because that's what conv does
		[mimi(k),ind_(k)] = max(w(bond));
	end
	[max_expand, ind] = max(mimi);
	bak = ind_(ind) + bond(1) - 1;	% Need to add bound(1) because the 'ind' repects the shorter 'bond' vector

	for (k = 1:percent)				% Now Shrink
		xi = x * (1 + (k-1)*1e-2);
		yi = interp1(x, y_synt, xi, 'linear', 0);		% Use extrap value = 0 and use this knowledge later
		n = 1;
		while (yi(n) == 0),		yi(n) = y_synt(1);		n = n + 1;	end		% Replace zeros by first val (Crude but ...)
		n = numel(yi);
		while (yi(n) == 0),		yi(n) = y_synt(end);	n = n - 1;	end		% Replace zeros by last val
		w = conv2(yi, y_ano, 'full');
		[mimi(k),ind_(k)] = max(w(bond));
	end
	[max_shrink, ind] = max(mimi);

	% Pick the maximum of the correlations and its index between expanding and shrinking
	if (max_expand > max_shrink),	lag = bak;
	else,							lag = ind_(ind) + bond(1) - 1;
	end

	shift = (lag - n_pts);

% --------------------------------------------------------------------------------------------------
function pinpointLine(obj, evt, h)
% Pin-point a hAgeLine_fit line and change its width and color.
% This type of line will be used as a boundary that some other isochrons guessings cannot cross
	handles = guidata(h);
	set(h, 'LineWidth',3, 'Color', [0.7 0.7 0.7], 'Tag', 'pinned')
	ui = get(get(h, 'UIContextMenu'),'Children');
	set(ui, 'Label', 'Delete me', 'Callback', 'delete(gco)')
	x = get(h, 'XData');
	if (isempty(handles.pinned))
		handles.pinned = x(1);
	else
		b = sort([handles.pinned x(1)]);		db = diff(b);	d = (db ~= 0);
		handles.pinned = b(d);			% This and the above line are the very guts of unique
	end
	handles.hAgeLine_fit = [];			% So that nex time a new hAgeLine_fit line will be created.
	guidata(handles.figure1, handles)

% --------------------------------------------------------------------------------------------------
function rectang_clicked_CB(obj,evt)
% Draw a rectangle that can be used to limit analysis (e.g. FFTs) to its XLim
	handles = guidata(obj);     % get handles
	try
		[p1,p2,hLine] = rubberbandbox(handles.axes1);
		cmenuHand = uicontextmenu('Parent',handles.figure1);
		set(hLine, 'UIContextMenu', cmenuHand);
		uimenu(cmenuHand, 'Label', 'Delete', 'Callback', 'delete(gco)');
	catch		% Don't know why but uisuspend sometimes breaks
		set(handles.figure1,'Pointer','arrow'),		return
	end
	y_lim = get(handles.axes1,'ylim');
	set(hLine, 'Ydata', [y_lim(1) y_lim(2) y_lim(2) y_lim(1) y_lim(1)])	% Make rect from y_min to y_max
	ui_edit_polygon(hLine)
	handles.hRect = hLine;
	guidata(handles.figure1, handles)

% --------------------------------------------------------------------------------------------------
function write_text_CB(obj, evt)
% Draw Texts
	pt = click_e_point(1,'crosshair');
	if (isempty(pt)),	return,		end
	h = text(pt(1),pt(2),0,'','Editing','on','VerticalAlignment','baseline','Margin',1);
	draw_funs(h, 'DrawText')		% Set uicontextmenu

% --------------------------------------------------------------------
function add_uictx_CB(hObject, handles)
% Tricky function either called externally to 'ecran' or activated when loading a file with DATENUM info
	handles = guidata(handles.figure1);		% Get an updated version since it may be an old one
	h = findobj(handles.figure1,'Label','Analysis');
	xx = get_inside_rect(handles);
	uimenu('Parent',h, 'Callback',@ecran_uiCB,...
			'Label','Filter (Butterworth)', 'Tag','filterButt', 'Sep', 'on');
	% Save original X label in appdata for easear access when we want to change it
	setappdata(handles.axes1,'XTickOrig',get(handles.axes1,'XTickLabel'))
	setappdata(handles.axes1,'xIsDatenum',true)		% For FFTs to know how to compute frequency

	if (isa(xx, 'cell')),	doit = xx{1}(end) > 365;
	else,					doit = xx(end) > 365;
	end
	if (doit)			% Assume days of the year. No datenum
		datetick(handles.axes1, 'x','keeplimits', 'keepticks')		% Make it auto right away
		uimenu(handles.cmenu_axes, 'Label', 'Date Format -> auto', 'Callback', {@SetAxesDate,'x'}, 'Sep','on');
		uimenu(handles.cmenu_axes, 'Label', 'Date Format -> dd-mmm-yyyy', 'Callback', {@SetAxesDate,1});
		uimenu(handles.cmenu_axes, 'Label', 'Date Format -> dd/mm/yy', 'Callback',    {@SetAxesDate,20});
		uimenu(handles.cmenu_axes, 'Label', 'Date Format -> dd/mm/yyyy', 'Callback',  {@SetAxesDate,24});
		uimenu(handles.cmenu_axes, 'Label', 'Date Format -> mm/dd/yy', 'Callback',    {@SetAxesDate,2});
		uimenu(handles.cmenu_axes, 'Label', 'Date Format -> mm/dd', 'Callback',       {@SetAxesDate,6});
		uimenu(handles.cmenu_axes, 'Label', 'Date Format -> yyyy', 'Callback',        {@SetAxesDate,10});
		uimenu(handles.cmenu_axes, 'Label', 'Date Format -> mmmyy', 'Callback',       {@SetAxesDate,12});
		uimenu(handles.cmenu_axes, 'Label', 'Date Format -> mmmyyyy', 'Callback',     {@SetAxesDate,28});
		uimenu(handles.cmenu_axes, 'Label', 'Date Format -> dd/mm', 'Callback',       {@SetAxesDate,19});
		uimenu(handles.cmenu_axes, 'Label', 'Date Format -> yy/mm/dd', 'Callback',    {@SetAxesDate,25});
		uimenu(handles.cmenu_axes, 'Label', 'Date Format -> yyyy/mm/dd', 'Callback',  {@SetAxesDate,26});
		uimenu(handles.cmenu_axes, 'Label', 'Date Format -> HH:MM', 'Callback',       {@SetAxesDate,15});
		uimenu(handles.cmenu_axes, 'Label', 'Date Format -> HH:MM:SS', 'Callback',    {@SetAxesDate,13});
		uimenu(handles.cmenu_axes, 'Label', 'Date Format -> dd.xxx', 'Callback',       @SetAxesDate);
	end

% --------------------------------------------------------------------
function filterButt_CB(hObject, handles)
% Normaly this function should only be called when dealing with dl tide data 
	if (isempty(handles.hLine)),	return,		end
	[xx, yy] = get_inside_rect(handles);
	res = filter_butter(xx, yy);
	h = ecran('reuse',xx,res(:,2),[],'Tide Removed');
	handNew = guidata(h);
	% Save original X label in appdata for easear access when we want to change it
	setappdata(handNew.axes1,'XTickOrig',get(handNew.axes1,'XTickLabel'))
	setappdata(handNew.axes1,'xIsDatenum',true)		% For FFTs to know how to compute frequency

	if (xx(end) > 365)			% Assume days of the year. No datenum
		datetick('x','keeplimits')		% Make it auto right away
		uimenu(handNew.cmenu_axes, 'Label', 'Date Format -> auto', 'Callback', {@SetAxesDate,'x'}, 'Sep','on');
		uimenu(handNew.cmenu_axes, 'Label', 'Date Format -> dd-mmm-yyyy', 'Callback', {@SetAxesDate,1});
		uimenu(handNew.cmenu_axes, 'Label', 'Date Format -> mm/dd/yy', 'Callback',    {@SetAxesDate,2});
		uimenu(handNew.cmenu_axes, 'Label', 'Date Format -> mm/dd', 'Callback',       {@SetAxesDate,6});
		uimenu(handNew.cmenu_axes, 'Label', 'Date Format -> HH:MM', 'Callback',       {@SetAxesDate,15});
		uimenu(handNew.cmenu_axes, 'Label', 'Date Format -> HH:MM:SS', 'Callback',    {@SetAxesDate,13});
		uimenu(handNew.cmenu_axes, 'Label', 'Date Format -> dd.xxx', 'Callback',       @SetAxesDate);
	end

% --------------------------------------------------------------------------------------------------
function x_is_time_CB(hObject, evt, opt)
% ...
	handles = guidata(hObject);
	if (isempty(handles.hLine)),	return,		end		% Nothing loaded yet
	if (handles.converted2dates)
		warndlg('I already did this once. No repetitions.', 'Warning'),		return
	end
	if (strcmp(get(handles.check_geog, 'Vis'), 'on'))
		errordlg('Nope. This is a spatial dataset, no time conversions.', 'Error'),		return
	end

	x_min = inf;	x_max = -inf;	
	if (strcmp(opt, 'DOY'))
		Y = fix(abs(str2double(inputdlg({'I need to know the year'},'Year',[1 30],{''}))));
		if (isnan(Y))
			warndlg('OK, you don''t tell me the year and I won''t show you dates', 'Warning')
			return
		end
		for (k = 1:numel(handles.hLine))
			DOY = get(handles.hLine(k),'XData');
			x = datenum(Y, 1, 1) + DOY;
			set(handles.hLine(k),'XData', x);
			x_min = min(x_min, min(x));		x_max = max(x_max, max(x));
		end
	elseif (strcmp(opt, 'DECY'))		% Here we have yyyy.xxxxx and need to convert to datenum time
		for (k = 1:numel(handles.hLine))
			x = get(handles.hLine(k),'XData');
			Years = fix(x);
			dn = datenum(Years, 1, 1);
			t = 365 + (~rem(Years, 4) & rem(Years, 100)) | ~rem(Years, 400);
			dias = (x - Years) .* t;
			dn = dn + dias;
			set(handles.hLine(k),'XData', dn);
			x_min = min(x_min, min(x));		x_max = max(x_max, max(x));
		end
	else
		return
	end
	set(handles.axes1, 'XLim', [x_min x_max])		% R13 needs this
	add_uictx_CB(handles.add_uictx, handles)
	handles.converted2dates = true;
	guidata(handles.figure1, handles)

% --------------------------------------------------------------------------------------------------
function handles = SetAxesDate(hObject,evt,opt)
% Set X axes labels when we know for sure X units are datenum days
	handles = guidata(hObject);
	if (nargin == 2)		% Sow the original dd.xxxxx
		set(handles.axes1,'XTickLabel', getappdata(handles.axes1,'XTickOrig'))
	elseif (ischar(opt))	% Automatic
		datetick(handles.axes1, 'x','keeplimits', 'keepticks')
	else
		datetick(handles.axes1, 'x', opt, 'keeplimits', 'keepticks')
	end

% --------------------------------------------------------------------
function ac = autocorr(x)
%AUTOCORR Computes normalized auto-correlation of vector X.
	[x,nshift] = shiftdim(x);
	maxlag = size(x,1) - 1;
	x = x(:);   m = size(x,1);
	% Compute Autocorrelation via FFT
	X = fft(x,2^nextpow2(2*m-1));
	ac = ifft(abs(X).^2);

	ac = real(ac);				% We want only the real part
	% Move negative lags before positive
	ac = [ac(end-maxlag+1:end,:);ac(1:maxlag+1,:)];
	ac = ac./ac(maxlag+1);		% Normalize by ac[0]

	% If first vector is a row, return a row
	ac = shiftdim(ac,-nshift);

% --------------------------------------------------------------------
function [Pxx,w] = psd(xw, Fs, nfft)
%Power Spectral Density estimate via periodogram method.
	N = length(xw);     xw = xw(:);
	if (nargin == 2)
		nfft  = max(256, 2^nextpow2(N));
	end

	nx = size(xw,2);
	xw = [xw; zeros(nfft-N,1)];     % pad with zeros (I REALY don't like this)
	if (nx~=1),  xw = xw.';  end;    clear nx;

	% Compute the periodogram power spectrum [Power] estimate
	Sxx =(abs(fft(xw)).^2)./N; 

	% Generate the frequency vector in [rad/sample] at which Sxx was computed
	w = 2.*pi.*(0 : 1/nfft : 1-1/nfft);

	% Compute the Power/freq (PSD), the Power and the frequency at which it is computed
	w = w(:);

	% Generate the spectrum
	if rem(nfft,2)			% odd
		select = 1:(nfft+1)/2;
		Sxx_unscaled = Sxx(select);
		Sxx = [Sxx_unscaled(1,:); 2*Sxx_unscaled(2:end,:)];  % Only DC is a unique point and doesn't get doubled
	else					% even
		select = 1:nfft/2+1;
		Sxx_unscaled = Sxx(select);
		Sxx = [Sxx_unscaled(1,:); 2*Sxx_unscaled(2:end-1,:); Sxx_unscaled(end,:)]; % Don't double unique Nyquist point
	end
	w = w(select);

	Pxx = Sxx./Fs;      % Scale by the sampling frequency to obtain the psd
	w = w.*Fs./(2.*pi); % Scale the frequency vector from rad/sample to Hz
	
% --------------------------------------------------------------------------------------
function [Pxx,w] = welch(x, Fs, varargin)
%WELCH Welch spectral estimation method.
% Acklamized version from ML code.

	[x,win,noverlap,k,L,nfft] = welchparse(x,varargin{:});

	LminusOverlap = L-noverlap;
	xStart = 1:LminusOverlap:k*LminusOverlap;
	xEnd   = xStart+L-1;
	Sxx = zeros(nfft,1); 
	for (i = 1:k)
		[Sxxk, w] = periodogram(x(xStart(i):xEnd(i)),win, nfft);
		Sxx  = Sxx + Sxxk;
	end

	Sxx = Sxx./k;		% Average the sum of the periodograms

	% Generate the spectrum
	if rem(nfft,2)			% odd
		select = 1:(nfft+1)/2;
		Sxx_unscaled = Sxx(select);
		Sxx = [Sxx_unscaled(1,:); 2*Sxx_unscaled(2:end,:)];  % Only DC is a unique point and doesn't get doubled
	else					% even
		select = 1:nfft/2+1;
		Sxx_unscaled = Sxx(select);
		Sxx = [Sxx_unscaled(1,:); 2*Sxx_unscaled(2:end-1,:); Sxx_unscaled(end,:)]; % Don't double unique Nyquist point
	end
	w = w(select);

	Pxx = Sxx./Fs;      % Scale by the sampling frequency to obtain the psd
	w = w.*Fs./(2.*pi); % Scale the frequency vector from rad/sample to Hz   

% -----------------------------------------------------------------------------
function [x,win,noverlap,k,L,nfft] = welchparse(x,varargin)
% Parse the inputs to the welch function.

	win = [];	noverlap = [];
	M = numel(x);
	x = x(:);
	if (numel(varargin) >= 1)
		win = varargin{1};
		if (numel(varargin) >= 2),	noverlap = varargin{2};		end
	end

	[L,noverlap,win] = segment_info(M,win,noverlap);	% Get the necessary info to segment x.

	nfft = max(256,2^nextpow2(L));
	k = fix((M-noverlap)./(L-noverlap));				% Compute the number of segments

%-----------------------------------------------------------------------------------------------
function [L,noverlap,win] = segment_info(M,win,noverlap)
%SEGMENT_INFO   Determine the information necessary to segment the input data.
%
%   Inputs:
%      M        - An integer containing the length of the data to be segmented
%      WIN      - A scalar or vector containing the length of the window or the window respectively
%                 (Note that the length of the window determines the length of the segments)
%      NOVERLAP - An integer containing the number of samples to overlap (may be empty)
%
%   Outputs:
%      L        - An integer containing the length of the segments
%      NOVERLAP - An integer containing the number of samples to overlap
%      WIN      - A vector containing the window to be applied to each section
%
%   The key to this function is the following equation:
%      K = (M-NOVERLAP)/(L-NOVERLAP)

	L = [];

	if isempty(win)			% Use 8 sections, determine their length
		if isempty(noverlap)		% Use 50% overlap
			L = fix(M./4.5);
			noverlap = fix(0.5.*L);
		else
			L = fix((M+7.*noverlap)./8);
		end
		win = hamming(L);
	else
		% Determine the window and its length (equal to the length of the segments)
		if (~any(size(win) <= 1) || ischar(win))
			error('welch:invalidWindow','The WINDOW argument must be a vector or a scalar.')
		elseif (length(win) > 1)	% WIN is a vector
			L = length(win);
		elseif (length(win) == 1)
			L = win;
			win = hamming(win);
		end
		if isempty(noverlap)		% Use 50% overlap
			noverlap = fix(0.5.*L);
		end
	end

	if (L > M)
		errmsg = 'The length of the segments cannot be greater than the length of the input signal.';
		error('welch:invalidSegmentLength',errmsg)
	end

	if (noverlap >= L)
		errmsg = 'The number of samples to overlap must be less than the length of the segments.';
		error('welch:invalidNoverlap',errmsg)
	end

% ----------------------------
function [P,f] = periodogram(x,win,nfft)
%   Sxx = PERIODOGRAM(X,WIN,NFFT) where x is a vector returns the
%   Power Spectrum over the whole Nyquist interval, [0, 2pi).
%
%    X           - Signal vector
%    WIN         - Window
%    NFFT        - Number of frequency points (FFT)

	xin = x .* win;		% Window the data

	% Evaluate the window normalization constant.  A 1/N factor has been omitted since it will cancel below.
	U = win' * win;  % compensates for the power of the window.

	% Compute the periodogram power spectrum estimate. A 1/N factor has been omitted since it cancels
	Xx = fft(xin,nfft);

	% Compute the whole frequency range, e.g., [0,2pi) to avoid round off errors.
	Fs = (2*pi);	
	freq_res = Fs/nfft;
	f = freq_res*(0:nfft-1)';

	Nyq = Fs/2;
	half_res = freq_res/2; % half the resolution

	% Determine if Npts is odd.
	isNPTSodd = false;
	if rem(nfft,2),		isNPTSodd = true;	end

	% Determine half the number of points.
	if (isNPTSodd),	halfNPTS = (nfft+1)/2;  % ODD
	else,			halfNPTS = (nfft/2)+1;  % EVEN
	end

	if (isNPTSodd)		% Adjust points on either side of Nyquist.
		f(halfNPTS)   = Nyq - half_res;
		f(halfNPTS+1) = Nyq + half_res;
	else				% Make sure we hit Nyquist exactly, i.e., pi or Fs/2 
		f(halfNPTS) = Nyq;
	end
	f(nfft) = Fs-freq_res;
	P = Xx .* conj(Xx) / U;      % Auto spectrum.

%---------------------------------------------------------------------
function w = hamming(n)
% w = (54 - 46*cos(2*pi*(0:m-1)'/(n-1)))/100;

	if ~rem(n,2),	half = n/2;			last = 0;
	else,			half = (n+1)/2;		last = 1;
	end
	x = (0:half-1)'/(n-1);
	w = 0.54 - 0.46 * cos(2*pi*x);
    w = [w; w(end-last:-1:1)];

% ---------------------------------------------------------------------------------
function rd = get_distances(x, y, geog, units, ellipsoide)
% Compute acumulated distances along line
	% Play safe with NaNs
	ix = isnan(x);
	if (any(ix)),		x(ix) = [];     y(ix) = [];		end
	iy = isnan(y);
	if (any(iy)),		x(iy) = [];     y(iy) = [];		end
	if (isempty(geog) || isempty(units) || units(1) == 'u'),	geog = false;	end
	if (geog)
		lat_i = y(1:end-1);   lat_f = y(2:end);
		lon_i = x(1:end-1);   lon_f = x(2:end);
		if (~isempty(ellipsoide))
			tmp = vdist(lat_i,lon_i,lat_f,lon_f, ellipsoide);
		else
			tmp = vdist(lat_i,lon_i,lat_f,lon_f);
		end

		switch units(1)
			case 'n',		scale = 1852;		% Nautical miles
			case 'k',		scale = 1000;		% Kilometers
			case 'm',		scale = 1;			% Meters
		end
		rd = [0; cumsum(tmp(:))] / scale;
	else
		xd = diff(x);		yd = diff(y);
		tmp = sqrt(xd.*xd + yd.*yd);
		rd = [0; cumsum(tmp(:))];
	end
	
% ------------------------------------------------------------------------------
function h = sticks(hAx,jd,u,v,ylims)
% STICKS  time series stick plot
%   
%      USAGE:  
%          h = timeplt([hAx,] jd,u,v [,ylims]);
%      where
%         jd = time vector (normaly a datenum vector)
%         u,v = vector components containing time the series data (wind?) 
%         ylims = ylimits of the panel plot. Autoscales if ylims is not set
%
%       outputs:
%            h = handles for stick plot (line)
%
% Original code by Rich Signell rsignell@usgs.gov (TIMEPLT) but stripped to bare minimuns

	if (nargin < 3)
		error('sticks:Unsuficient number of inputs')
	elseif (~ishandle(hAx))
		jd = hAx;	u = jd;		v = u;
		if (nargin == 4),	ylims = v;
		else,				ylims = [];
		end
		hAx = gca;
	else
		if (nargin == 5),	ylims = v;
		else,				ylims = [];
		end		
	end

	%-------------------------------------------------------------------
	%  Set the cutoff for different types of Gregorian axis types
	%  You can adjust these to suit your preferences.  For example, if your
	%  plot got labeled with days, but you want hours, increase "daycut" 
	%  (until it's larger than the "fac" for your plot).
	yearcut = 250;	moncut = 20;	daycut = 0.2;	mincut = 0.05;

	% Don't clip that data!
	%set(0,'DefaultLineclipping','off')

	u = u(:);
	jd0 = jd(1);
	jd1 = jd(numel(jd));

	unit_back = get(hAx, 'units');
	set(hAx,'units','pixels');
	pos = get(hAx,'pos');
	xlen = pos(3);
	font = get(hAx,'fontsize');
	label_width=5*font;
	nlabel = floor(xlen/label_width);
	set(hAx,'units','normalized');
	fac = (jd1-jd0) / nlabel;  %number of days per label
	% adjust xfactor for subsequent stretching by Gregorian Date
	if (fac > yearcut)
		xlims = [jd0-180 jd1+180];
	elseif (yearcut > fac && fac > moncut)
		xlims = [jd0-25 jd1+25];
	elseif (moncut > fac && fac > daycut)
		xlims = [floor(jd0)-.5 ceil(jd1)+.5];
	elseif (daycut > fac && fac > mincut)
		xlims = [jd0-1/48 jd1+1/48];
	elseif (mincut > fac)		% leave 2.5% off of each side.
		time_offset = (jd1-jd0)*0.025;
		xlims = [jd0-time_offset jd1+time_offset];
	end

	if (isempty(ylims)),	ylims = [min(v) max(v)]*1.1;	end
	set(hAx,'units','pixels');
	ppos = get(hAx,'position');
	set(hAx,'units','norm');
	uscale = (diff(xlims)/diff(ylims)) * (ppos(4)/ppos(3));
	up = uscale * u;
	yp = zeros(size(jd));
	xplot = ones(numel(jd),2);
	yplot = xplot;
	xplot(:,1) = jd(:);
	xplot(:,2) = jd(:) + up;
	xplot(:,3) = jd(:);
	yplot(:,1) = yp(:);
	yplot(:,2) = yp(:) + v(:);
	yplot(:,3) = yp(:) * nan;
	xplot = xplot';
	yplot = yplot';
	h = plot(xplot(:),yplot(:),'-', 'Parent', hAx);
	set(hAx,'xlim',xlims, 'ylim',ylims, 'units', unit_back);

% ------------------------------------------------------------------------------
function [anoma, age_line, obliquity] = magmodel(hAxesMagBar, reversalsFile, dxyp, fDec, fInc, speed, ...
	dir_spread, dir_profil, spreadObliqDir, contam)
% hAxesMagBar	Must contain the handle of axes where to plot the Mag Bars (axes2 of the 'Ecran' fig)
% spreadObliqDir	Is the spreaging obliquity (often, but not always, is zero)
% contam		The Tissot & Patriat's contamination factor
%
% NOTE: dir_spread can be set via OPTcontrol.txt, if it was not than it defaults to equal dir_profil
%
% This function was adapted from the MAGMOD program
% "MODMAG, a MATLAB program to model marine magnetic anomalies."
% V�ronique Mendel, Marc Munschy and Daniel Sauter. Computers & Geosciences 31 (2005) 589�597
% Intention is to clean it more or eventually re-write it (for example it doesn't account
% for possibly different Remanent & Inducted mags).

	if (nargin < 10),	contam = 1;		end
	if (size(dxyp,2) == 3)		% If depth is not provided, default to const = 2.5 km
		dxyp = [dxyp(:,1:3) ones(size(dxyp,1),1)*2.5];
	end

	zObs = 0;		magAtAxe = 15;		magFlatOfEachBlock = 5;
	psubsi = 0.35;			% Coefficient of thermal subsidence equation
	thickness = 0.5;
	speed = speed * 10;		% From full rate in cm/year to rate in km/Ma 

	fid = fopen(reversalsFile,'r');
	todos = fread(fid,'*char');
	[chron, age_start, age_end, s.age_txt] = strread(todos,'%s %f %f %s');
	fclose(fid);    clear todos
	BA = zeros(numel(age_start)*2,2);
	BA(1:2:end-1,1) = age_start;	BA(2:2:end,1) = age_end;
	BA(1:2:end-1,2) = age_end;
	BA(2:2:end-2,2) = age_start(2:end);
	BA(end,:) = [];

	distAlongProfile = dxyp(:,1);
	profileDepth = dxyp(:,4);
	ind = isnan(profileDepth);
	if (any(ind))			% Many files have gaps in bathymetry. Reinvent it
		profileDepth(ind) = interp1(distAlongProfile(~ind), profileDepth(~ind), distAlongProfile(ind));
	end

	nBlocks = size(BA,1);
	nPts = numel(distAlongProfile);		% Number of points
	stat_z = zeros(nPts,1) + zObs;		% Depth of the points where the magnetic anomaly will be compute

	% Determination of the age limits of normal and inverse polarity bodies and
	% of their respecting magnetization

	twiceNBlocks = (nBlocks*2) - 1;

	blockAge = zeros(twiceNBlocks,2);
	blockMag = zeros(twiceNBlocks,1);
	blockAge(1:nBlocks-1,1) = -BA(nBlocks:-1:1+1,2);
	blockAge(1:nBlocks-1,2) = -BA(nBlocks:-1:1+1,1);
	blockAge(nBlocks,:) = [-BA(1,2) BA(1,2)];
	blockAge(nBlocks+1:twiceNBlocks,:) = BA(1+1:nBlocks,:);
	blockMag(nBlocks) = magAtAxe;
	blockMag(nBlocks-2:-2:1) = magFlatOfEachBlock;
	blockMag(nBlocks+2:2:twiceNBlocks) = magFlatOfEachBlock;
	blockMag(nBlocks-1:-2:1) = -magFlatOfEachBlock;
	blockMag(nBlocks+1:2:twiceNBlocks) = -magFlatOfEachBlock;

	% Calculation of magnetized bodies position in km
	polygon_x = zeros(4,twiceNBlocks);
	polygon_x(1,:) = blockAge(:,1)' * speed / 2;
	polygon_x(2,:) = blockAge(:,2)' * speed / 2;
	polygon_x(3,:) = polygon_x(2,:);
	polygon_x(4,:) = polygon_x(1,:);

	% Before calculation of the magnetic anomaly, the spreading direction has
	% to be less than 90� away from the profile direction in order to be plot
	% in the right sense of distance. To do this we first calculate the obliquity
	% between the direction of the profile and the spreading direction.
	[dir_spread, obliquity] = obliquity_care(dir_spread, dir_profil, spreadObliqDir);
	if (obliquity ~= 0)
		if (obliquity > 0)
			polygon_x = polygon_x / cos (obliquity * pi / 180);
		else
			% Rarer cases where ridge spreading is oblique and the profile lies inside the obliquity cone
			polygon_x = polygon_x * cos (obliquity * pi / 180);
		end
	end

	hMagBar = findobj(hAxesMagBar, 'type', 'patch', 'Tag', 'MagBarCode');
	xx = get(hMagBar,'XData');
	ind = find((xx(1) - blockAge(:,1)) > 0);	% Find index of closest block start of displyed bricks and those from file
	ind = ind(end);								% The last one is closest from the left (starting) side
	f = (xx(1) - blockAge(ind,1)) / (blockAge(ind,2) - blockAge(ind,1));
	distAlongProfile = distAlongProfile + polygon_x(1,ind) + f * (polygon_x(2,ind) - polygon_x(1,ind));

	% Calculation of the magnetized bodies depth
	polygon_z = zeros(4,twiceNBlocks);

	ind = find(polygon_x(1,:) < distAlongProfile(1));	% Find start block limits to the left of profile start
	if ~isempty(ind)
		maxlignm11 = max(ind);
		if (polygon_x(1,maxlignm11) < 0)
			polygon_z(1,ind) = profileDepth(1) + psubsi*sqrt(blockAge(maxlignm11,1)-blockAge(ind,1)');
		else
			polygon_z(1,ind) = profileDepth(1);
		end
		polygon_z(4,ind) = polygon_z(1,ind) + thickness;
	end

	ind = find(polygon_x(2,:) < distAlongProfile(1));	% Find end block limits to the left of profile start
	if ~isempty(ind)
		maxlignm12 = max(ind);
		if polygon_x(2,maxlignm12) < 0
			polygon_z(2,ind) = profileDepth(1) + psubsi*sqrt(blockAge(maxlignm12,2) - blockAge(ind,2)');
		else
			polygon_z(2,ind) = profileDepth(1);
		end
		polygon_z(3,ind) = polygon_z(2,ind) + thickness;
	else
		maxlignm12 = 0;
	end

	ind = find(polygon_x(1,:) >= distAlongProfile(end));	% Find start block limits to the right of profile end
	if ~isempty(ind)
		minlignm21 = min(ind);
		if (polygon_x(1,minlignm21) > 0)
			polygon_z(1,ind) = profileDepth(end) + psubsi*sqrt(blockAge(ind,1)' - blockAge(minlignm21,1));	
		else
			polygon_z(1,ind) = profileDepth(end);
		end
		polygon_z(4,ind) = polygon_z(1,ind) + thickness;
	else
		minlignm21 = twiceNBlocks + 1;
	end

	ind = find(polygon_x(2,:) >= distAlongProfile(end));	% Find end block limits to the right of profile end
	if ~isempty(ind)
		minlignm22 = min(ind);
		if polygon_x(2,minlignm22) > 0
			polygon_z(2,ind) = profileDepth(end) + psubsi*sqrt(blockAge(ind(:),2)' - blockAge(minlignm22,2));	
		else
			polygon_z(2,ind) = profileDepth(end);
		end
		polygon_z(3,ind) = polygon_z(2,ind) + thickness;
	end

	% Now find the block limits that are contained inside the profile
	ind = find(polygon_x(1,:) >= distAlongProfile(1) & polygon_x(1,:) < distAlongProfile(end));
	if ~isempty(ind)
		polygon_z(1,ind) = interp1(distAlongProfile, profileDepth, polygon_x(1,ind));
		polygon_z(4,ind) = polygon_z(1,ind) + thickness;
	end
	ind = find(polygon_x(2,:) >= distAlongProfile(1) & polygon_x(2,:) < distAlongProfile(end));
	if ~isempty(ind)
		polygon_z(2,ind) = interp1(distAlongProfile, profileDepth, polygon_x(2,ind));
		polygon_z(3,ind) = polygon_z(2,ind) + thickness;
	end

	PolXX = cell(1,twiceNBlocks);
    PolZZ = cell(1,twiceNBlocks);

	for i = 1:twiceNBlocks
		PolXX{i} = [polygon_x(:,i); polygon_x(1,i)];
		PolZZ{i} = [polygon_z(:,i); polygon_z(1,i)];
	end

	for i = maxlignm12+1:minlignm21-1
		ptdist = find(distAlongProfile > polygon_x(1,i)+0.00001 & distAlongProfile < polygon_x(2,i)-0.00001);
		if ~isempty(ptdist)
			tempox1 = distAlongProfile(ptdist);
			tempoz1 = profileDepth(ptdist);
			tempox2 = flipud(tempox1);
			tempoz2 = flipud(tempoz1+thickness);
			tempox3 = [polygon_x(1,i);tempox1;polygon_x(2,i);polygon_x(3,i);tempox2;polygon_x(4,i)];
			tempoz3 = [polygon_z(1,i);tempoz1;polygon_z(2,i);polygon_z(3,i);tempoz2;polygon_z(4,i)];
			PolXX{i}= [tempox3; polygon_x(1,i)];
			PolZZ{i}= [tempoz3; polygon_z(1,i)];
		end
	end

	% Re-positionning of the magnetized bodies if the contamination coefficient is different from 1
	if (contam ~= 1)
		for (i = 1:twiceNBlocks)
			PolXX{i} = PolXX{i} * contam;
		end
		distAlongProfile = distAlongProfile * contam;
	end

	% Calculation of the magnetic anomaly created by the magnetized bodies
	anoma = calcmag(twiceNBlocks,fInc,fDec,dir_spread,blockMag,distAlongProfile,stat_z,nPts,PolXX,PolZZ);

	if (nargout >= 2)						% Calculate the ages. 
		age_line = distAlongProfile / speed * 2;
	end

% ---------------------------------------------------------------------------------------
function [dir_spread, obliquity] = obliquity_care(dir_spread, dir_profil, ridgeObliquity)
% Compute the obliquity between the direction of the profile and the opening direction
% but taking into account that the Ridge my open aslant as well.
% OBLIQUITY Is positive when DIR_PROFIL is outside the obliquity cone and negative otherwise.
% The 'obliquity cone' exists only for oblique spreading (ridgeObliquity ~= 0) and is deffined
% (by Me) as having an angle twice that of the spreading direction and the Ridge normal. That
% is, the 'ridgeObliquity', and whose axial line is the ridge normal.

	if (nargin < 3),	ridgeObliquity = 0;		end

	% First bring the profile and spreading directions to the same side of the 180 deg barrier.
	obliquity = dir_profil - dir_spread;
	if (abs(obliquity) > 90)
		temp1 = mod(obliquity,90);
		temp2 = mod(obliquity,-90);
		if (abs(temp1) <= abs(temp2)),		obliquity = temp1;
		else,								obliquity = temp2;
		end
		dir_spread = dir_profil - obliquity;
	end
	obliquity = abs(obliquity);				% Remember, signal counts. Positive ==> 'outer' obliquity

	% End of the story?
	if (~ridgeObliquity),		return,		end		% We are done, bye

	if (dir_spread > 180)		% Let's call it the left side branch
		if ((dir_profil <= dir_spread) || (dir_profil >= dir_spread + 2*ridgeObliquity))
			obliquity = abs(dir_profil - dir_spread);	% Simpler case.
		else
			obliquity = -abs(ridgeObliquity - mod(dir_profil - dir_spread, ridgeObliquity));
		end
	else						% The right side branch
		if ((dir_profil >= dir_spread + 2*ridgeObliquity) || (dir_profil <= dir_spread))
			obliquity = abs(dir_profil - dir_spread);	% Simpler case.
		else
			obliquity = -abs(ridgeObliquity - mod(dir_profil - dir_spread, ridgeObliquity));
		end
	end

% ---------------------------------------------------------------------
function anoma = calcmag(nb_struct,fInc,fDec,dir_spread,blockMag,stat_x,stat_z,nPts,PolXX,PolZZ)
% Calculation of the magnetic anomaly created by magnetized bodies

	D2R = pi / 180;
	magInc(1:nb_struct,1) = fInc;
	magDec(1:nb_struct,1) = fDec;
    dir_anomag = dir_spread + 90;

	c1 = sin(fInc*D2R);    
	c2 = cos(fInc*D2R) * cos(dir_spread*D2R - fDec*D2R);

	d1 = sin(magInc*D2R);
	d2 = cos(magInc*D2R).*cos((dir_anomag-90)*D2R - magDec*D2R);
	d3 = 200 * blockMag;

	anomax = 0;		anomaz = 0;

	for (k = 1:nb_struct)
		n = numel(PolXX{k});
		[amx,amz] = fcalcmagpt(n,stat_x,stat_z,nPts,PolXX{k},PolZZ{k},d1(k),d2(k),d3(k));
		anomax = anomax + amx;
		anomaz = anomaz + amz;
	end

	anoma  = c2*anomax + c1*anomaz;

% --------------------------------------------------------------------
function [amxx,amzz] = fcalcmagpt(nbps,stax,staz,nbsta,polxxm,polzzm,dd1,dd2,dd3)
% Function to calculate the magnetized anomaly create by each point of a magnetized body

	matstax = repmat(stax,1,nbps-1);
	matstaz = repmat(staz,1,nbps-1);
	matpolxx = repmat(polxxm',nbsta,1);
	matpolzz = repmat(polzzm',nbsta,1);

	x1 = matpolxx(:,1:(nbps-1)) - matstax(:,1:(nbps-1));
	z1 = matpolzz(:,1:(nbps-1)) - matstaz(:,1:(nbps-1));
	x2 = matpolxx(:,2:nbps) - matstax(:,1:(nbps-1));
	z2 = matpolzz(:,2:nbps) - matstaz(:,1:(nbps-1));

	indx1 = find(x1==0);
	if (~isempty(indx1)),		x1(indx1) = 1e-11;		end
	indz1 = find(z1==0);
	if (~isempty(indz1)),		z1(indz1) = 1e-11;		end
	indx2 = find(x2==0);
	if (~isempty(indx2)),		x2(indx2) = 1e-11;		end
	indz2 = find(z2==0);
	if (~isempty(indz2)),		z2(indz2) = 1e-11;		end

	th1 = atan2(z1,x1);
	th2 = atan2(z2,x2);
	t12 = th1-th2;
	z21 = z2-z1;
	x21 = x2-x1;
	xz12= x1.*z2-x2.*z1;
	r21s= x21.*x21+z21.*z21;
	r1s = x1.^2+z1.^2;
	r2s = x2.^2+z2.^2;
	rln = 0.5*log(r2s./r1s);

	p=(xz12./r21s).*((x1.*x21-z1.*z21)./r1s-(x2.*x21-z2.*z21)./r2s);
	q=(xz12./r21s).*((x1.*z21+z1.*x21)./r1s-(x2.*z21+z2.*x21)./r2s);

	f1 = (t12.*z21-rln.*x21)./r21s;
	f2 = (t12.*x21 + rln.*z21)./r21s;

	dxx = p + z21.*f1;
	dxz = q - x21.*f1;
	dzz = -p + x21.*f2;
	dzx = q - z21.*f2;

	amxx = dd3*(dd1*sum(dxz,2)+dd2*sum(dxx,2));
	amzz = dd3*(dd1*sum(dzz,2)+dd2*sum(dzx,2));
% ------------------------------------------------------------------------------

% -----------------------------------------------------------------------------
function figure1_CloseRequestFcn(hObject, eventdata)
	set(hObject, 'vis', 'off'),		pause(0.05)		% To avoid ugly noticeable resizing before death
	handles = guidata(hObject);
	if (isempty(handles)),		delete(gcf),	return,		end
	if (~isempty(handles.polyFig))
		try		delete(handles.polyFig),	end
	end
	delete(handles.figure1)

% --------------------------------------------------------------------
function figure1_ResizeFcn(hObj, evt)
% Something I did sometime, somewhere screwed the automatic rescaling while resizing
% Make it work again.
	handles = guidata(hObj);
	if (isempty(handles)),      return,     end
	posF = get(handles.figure1,'Pos');	
	posA1 = get(handles.axes1,'Pos');		posA2 = get(handles.axes2,'Pos');
	posA1(4) = posF(4) - posA1(2) - posA2(4);
	posA1(3) = posF(3) - posA1(1) - 3;
	posA2(2) = posA1(2) + posA1(4);
	posA2(3) = posF(3) - posA2(1) - 3;
	set(handles.axes1,'Pos', posA1);		set(handles.axes2,'Pos', posA2);

	% Drag the Coordinates StatusBar arround too.
	displayBar = findobj(handles.figure1, 'Tag', 'pixValStsBar');
	pos = get(displayBar, 'Pos');
	pos(2) = posA2(2) + 1;
	set(displayBar, 'Pos', pos)

% --- Creates and returns a handle to the GUI figure. 
function h1 = ecran_LayoutFcn(opt)

	if (nargin)						% Supposedly the Fig's width and height, but not tested
		fw = opt(1);	fh = opt(2);
	else
		fw = 814;	fh = 389;		% Default width and height
	end

	h1 = figure('Position',[500 400 fw fh],...
		'Color',get(0,'factoryUicontrolBackgroundColor'),...
		'CloseRequestFcn',@figure1_CloseRequestFcn,...
		'ResizeFcn',@figure1_ResizeFcn,...
		'DoubleBuffer','on',...
		'MenuBar','none',...
		'Name','XY view',...
		'NumberTitle','off',...
		'RendererMode','auto',...
		'FileName','plotxy',...
		'Vis','off',...
		'Tag','figure1');
	
	setappdata(h1,'IAmAEcran',true)		% Use this appdata to identify this type of figure

	x0  = 40;	y0 = 48;
	w   = fw - x0 - 3;			% Dafault = 771
	a2h = 21;
	a1h = fh - y0 - a2h + 1;	% Default = 321
	a2y0 = fh - a2h + 1;		% Default = 369

axes('Parent',h1, 'Units','pixels', 'Position',[x0 a2y0 w a2h], 'Vis','off', 'Tag','axes2');
axes('Parent',h1, 'Units','pixels', 'Position',[x0 y0   w a1h], 'UserData','XY', 'NextPlot','Add', 'Tag','axes1');

uicontrol('Parent',h1, 'Position',[40 2 161 23],...
'Callback',@ecran_uiCB,...
'String','Geographical coordinates',...
'Tooltip',sprintf(['Check this if your data is in geographical coordinates.\n' ...
			'You will than be able to see and save the profile in km (or m) vs z.']),...
'Style','checkbox',...
'Tag','check_geog');

uicontrol('Parent',h1, 'Position',[360 2 160 23],...
'BackgroundColor',[1 1 1],...
'Callback',@ecran_uiCB,...
'String','Horizontal coords (data units)', ...
'Style','popupmenu',...
'Value',1,...
'Tooltip', 'Select horizontal display coordinates', ...
'Tag','popup_selectPlot');

uicontrol('Parent',h1, 'Position',[fw-150-2 2 150 23],...
'BackgroundColor',[1 1 1],...
'Callback',@ecran_uiCB,...
'String',{'Save Line on disk'; 'distance Z (data units, text)'; 'distance Z (data units, binary)'; 'distance Z (km, text)'; 'distance Z (km, binary)'; 'distance Z (NM, text)'; 'distance Z (NM, binary)'; 'X Y Z (data units, text)'; 'X Y Z (data units, binary)' },...
'Style','popupmenu',...
'Value',1,...
'Tooltip', 'Choose how to save the line', ...
'Tag','popup_selectSave');

h10 = uimenu('Parent',h1,'Label','File','Tag','menuFile');

uimenu('Parent',h10, 'Callback',@ecran_uiCB, 'Label','Open', 'Tag','FileOpen');
uimenu('Parent',h10, 'Callback',@ecran_uiCB, 'Label','Save', 'Tag','FileSave');
uimenu('Parent',h10, 'Callback',@ecran_uiCB, 'Label','Save Red Markers', 'Vis', 'off', 'Tag','FileSaveRedMark');
uimenu('Parent',h10, 'Callback',@ecran_uiCB, 'Label','Paste line', 'Tag','Ctrl_v', 'Accel','v')
hSe = uimenu('Parent',h10,'Label','Session','Sep','on');
uimenu('Parent',hSe, 'Callback',@ecran_uiCB, 'Label','Open', 'Tag','FileOpenSession');
uimenu('Parent',hSe, 'Callback',@ecran_uiCB, 'Label','Save', 'Tag','FileSaveSession');

hSc = uimenu('Parent',h10,'Label','Save GMT script','Sep','on');
uimenu('Parent',hSc, 'Callback','write_gmt_script(guidata(gcbo),''bat'')','Label','dos batch');
%uimenu('Parent',hSc, 'Callback','write_gmt_script(guidata(gcbo),''csh'')','Label','bash script');
uimenu('Parent',hSc, 'Callback','plot_composer(guidata(gcbo))','Label','bash script');

uimenu('Parent',h10, 'Callback','ecran','Label','New','Separator','on');
uimenu('Parent',h10, 'Callback',@ecran_uiCB, 'Label','Export...', 'Tag','FileExport', 'Sep','on');
uimenu('Parent',h10, 'Callback','print -dsetup', 'Label','Print Setup', 'Separator','on');
uimenu('Parent',h10, 'Callback',@ecran_uiCB, 'Label','Print...', 'Tag', 'FilePrint');

h17 = uimenu('Parent',h1, 'Label','Analysis');
uimenu('Parent',h17, 'Callback',@ecran_uiCB, 'Label','Remove Mean',    'Tag','AnalysisRemoveMean');
uimenu('Parent',h17, 'Callback',@ecran_uiCB, 'Label','Remove Trend',   'Tag','AnalysisRemoveTrend');
uimenu('Parent',h17, 'Callback',@ecran_uiCB, 'Label','Fit polynomial', 'Tag','AnalysisFitPoly');

h20 = uimenu('Parent',h17, 'Label','FFT', 'Separator','on');

uimenu('Parent',h20, 'Callback',@ecran_uiCB, 'Label','Amplitude Spectrum', 'Tag','AnalysisFFT_AmpSpectrum');
uimenu('Parent',h20, 'Callback',@ecran_uiCB, 'Label','Power Spectrum Density', 'Tag','AnalysisFFT_PSD');
uimenu('Parent',h20, 'Callback',@ecran_uiCB, 'Label','PSD (Welch method)', 'Tag','AnalysisFFT_PSD');

uimenu('Parent',h17, 'Callback',@ecran_uiCB, 'Label','Autocorrelation',  'Tag','AnalysisAutocorr');
uimenu('Parent',h17, 'Callback',@ecran_uiCB, 'Label','Smoothing Spline', 'Tag','AnalysisSmoothSpline', 'Sep','on');
uimenu('Parent',h17, 'Callback',@ecran_uiCB, 'Label','Filter',           'Tag','AnalysisFilter');
uimenu('Parent',h17, 'Callback',@ecran_uiCB, 'Label','1 st derivative',  'Tag','Analysis1derivative');
uimenu('Parent',h17, 'Callback',@ecran_uiCB, 'Label','2 nd derivative',  'Tag','Analysis2derivative');

uimenu('Parent',h17, 'Callback',@ecran_uiCB, 'Label','Activate extensional measuring', 'Tag', 'extensional', 'Sep','on');
hSh = uimenu('Parent',h17,'Label','Heaves', 'Tag', 'Heaves', 'Vis', 'off');
uimenu('Parent',hSh, 'Callback',@ecran_uiCB, 'Label','Plot Heaves', 'Tag','plotHeaves');
uimenu('Parent',hSh, 'Callback',@ecran_uiCB, 'Label','Plot Exx',    'Tag','plotExx');
uimenu('Parent',hSh, 'Callback',@ecran_uiCB, 'Label','Save Heaves', 'Tag','saveHeaves');

uimenu('Parent',h17, 'Callback','escorrega(''vert'',gcf)', 'Label','Show Vertical Exageration', 'Sep','on');

% Here we provide a hiden entry to activate functions of interest to tide analysis (porta do cavalo)
uimenu('Parent',h17,'Callback',@ecran_uiCB,'Vis','off','Tag','add_uictx');

h21 = uimenu('Parent',h1, 'Label','Misc');
uimenu('Parent',h21, 'Callback',{@ecran_uiCB, 'DOY'}, 'Label','X axis is decimal Day-Of-Year', 'Tag','x_is_time');
uimenu('Parent',h21, 'Callback',{@ecran_uiCB, 'DECY'},'Label','X axis is decimal year', 'Tag','x_is_time');

uicontrol('Parent',h1, 'Position',[85 8 51 22],...
'BackgroundColor',[1 1 1],...
'Callback',@ecran_uiCB,...
'String','',...
'Style','edit',...
'Tooltip', sprintf(['Age at which we start ploting the bars. If older than "End age"\n' ...
	'the bar code is plotted reversed. That is, from older to younger ages']),...
'Tag','edit_startAge',...
'Visible','off');

uicontrol('Parent',h1, 'Position',[192 8 75 23],...
'String','Zero age?',...
'Tooltip','Start and end ages passes through zero',...
'Style','checkbox',...
'Tag','check_zeroAge',...
'Vis','off');

uicontrol('Parent',h1, 'Position',[291 8 51 22],...
'BackgroundColor',[1 1 1],...
'Callback',@ecran_uiCB,...
'String','',...
'Style','edit',...
'Tooltip', 'Age at which we stop ploting the bars.',...
'Tag','edit_ageEnd',...
'Vis','off');

uicontrol('Parent',h1, 'Position',[372 8 101 21],...
'Callback',@ecran_uiCB,...
'String','Create Mag Bar',...
'Tooltip','Create a magnetic code bar on top of figure',...
'Tag','push_magBar',...
'Vis','off');

uicontrol('Parent',h1, 'Position',[31 13 52 14],...
'HorizontalAlignment','right',...
'String','Start age',...
'Style','text', ...
'Tag','text_startAge', ...
'Vis','off');

uicontrol('Parent',h1, 'Position',[236 13 52 14],...
'HorizontalAlignment','right',...
'String','End age',...
'Style','text', ...
'Tag','text_endAge', ...
'Vis','off');

uicontrol('Parent',h1, 'Position',[491 8 91 21],...
'Callback',@ecran_uiCB,...
'String','Synthetic RTP',...
'Tooltip','Create a synthetic profile reduced to the Pole',...
'Tag','push_syntheticRTP', ...
'Vis','off');

uicontrol('Parent',h1, 'Position',[596 9 121 17],...
'BackgroundColor',[0.9 0.9 0.9],...
'Callback',@ecran_uiCB,...
'Style','slider',...
'Min',0.5,...
'Max',1.0,...
'Val',1.0,...
'Tag','slider_filter',...
'Tooltip','Contamination factor ([0.5 1])',...
'Vis','off');

uicontrol('Parent',h1, 'Position',[725 9 55 20],...
'BackgroundColor',[1 1 1],...
'Callback',@ecran_uiCB,...
'String','', ...
'Style','popupmenu',...
'Value',1,...
'Tag','popup_ageFit',...
'Vis','off');

uicontrol('Parent',h1, 'Position',[729 8 51 22],...
'BackgroundColor',[1 1 1],...
'Callback',@ecran_uiCB,...
'String','',...
'Style','edit',...
'Tooltip', 'Fit synthetic curve at this age by correlation to measured profile.',...
'Tag','edit_ageFit',...
'Vis','off');

uicontrol('Parent',h1, 'Position',[780 8 26 21],...
'Callback',@ecran_uiCB,...
'String','Fit',...
'Tag','push_ageFit',...
'Vis','off');

function ecran_uiCB(hObject, evt, varargin)
% This function is executed by the callback and than the handles is allways updated.
	feval([get(hObject,'Tag') '_CB'], hObject, guidata(hObject), varargin{:});

%============================================================================
function varargout = ecran_trend1d(varargin)
% Little help figure where to select the order of polynomial to fit
% The fit is done with the trend1d_m MEX because it allows robust fitting

	hObject = figure('Vis','off');
	ecran_trend1d_LayoutFcn(hObject);
	handles = guihandles(hObject);
	move2side(hObject,'center');

	handles.hCallingAx = varargin{1};
	handles.xy = varargin{2};
	if (size(handles.xy, 2) > 2)		% X,Y must be column vectors
		handles.xy = handles.xy';
	end

	handles.polyDeg = 1;
	guidata(hObject, handles);
	set(hObject,'Vis','on');
	if (nargout),	varargout{1} = hObject;		end

% --------------------------------------------------------------------
function edit_polDeg_CB(hObject, handles)
	xx = abs(fix(str2double(get(hObject,'String'))));
	if (isnan(xx))
		set(hObject,'String', handles.polyDeg),		return
	end
	handles.polyDeg = xx;
	guidata(handles.figure1, handles)

% --------------------------------------------------------------------
function push_OK_CB(hObject, handles)
	opt_N = sprintf('-N%d', handles.polyDeg + 1);
	if (get(handles.check_robust, 'Val')),	opt_N = [opt_N 'r'];	end
	par = [];
	if (handles.polyDeg == 1)		% For linear trends compute also the p-value
		[out,par] = trend1d_m(handles.xy, '-Fxm', opt_N, '-P','-R');
	else
		out = trend1d_m(handles.xy, '-Fxm', opt_N);
	end
	
	h = line('XData', out(:,1), 'YData', out(:,2), 'Parent', handles.hCallingAx, 'Tag','fitted');
	
	% Compute the model parameters (trend1d_m only computes them in the linear case)
	p = polyfit(out(:,1), out(:,2), handles.polyDeg);
	
	% and put them on the line's uicontextmenu
	cmenuHand = uicontextmenu('Parent',get(handles.hCallingAx,'Parent'));
	set(h, 'UIContextMenu', cmenuHand);
 	uimenu(cmenuHand, 'Label', 'Poly Coefficients');
	p = num2str(p);
	if (~isempty(par))			% We also have a p-values
		p = [p ' [p-val = ' sprintf('%.2f]', par(end))];
	end
	uimenu(cmenuHand, 'Label', num2str(p));
	uimenu(cmenuHand, 'Label', 'Delete this line', 'Callback', 'delete(gco)', 'Sep', 'on');


% --- Creates and returns a handle to the GUI figure. 
function ecran_trend1d_LayoutFcn(h1)

set(h1, 'Position',[520 755 241 60],...
'Color',get(0,'factoryUicontrolBackgroundColor'),...
'MenuBar','none',...
'Name','Fit polynomial',...
'NumberTitle','off',...
'Resize','off',...
'HandleVisibility','callback',...
'Tag','figure1');

uicontrol('Parent',h1, 'Position',[161 38 75 15],...
'String','Robust Fit',...
'Style','checkbox',...
'TooltipString','Do a robust fit. See trend1d (GMT) manual to further details',...
'Tag','check_robust');

uicontrol('Parent',h1, 'Position',[111 34 30 21],...
'BackgroundColor',[1 1 1],...
'Callback',@ecran_trend1d_uiCB,...
'String','1',...
'Style','edit',...
'TooltipString','"1" means linear trend; "2" a quadratic model, and so on.',...
'Tag','edit_polDeg');

uicontrol('Parent',h1, 'Position',[10 37 100 15],...
'HorizontalAlignment','left',...
'String','Polynomial degree',...
'Style','text');

uicontrol('Parent',h1, 'Position',[164 6 66 21],...
'Callback',@ecran_trend1d_uiCB,...
'FontName','Helvetica',...
'FontSize',9,...
'String','OK',...
'Tag','push_OK');

function ecran_trend1d_uiCB(hObject, eventdata)
% This function is executed by the callback and than the handles is allways updated.
	feval([get(hObject,'Tag') '_CB'],hObject, guidata(hObject));

%============================================================================
function varargout = bandpass(varargin)
% Helper function to select frequencies to do bandpass filtering

	hObject = figure('Tag','figure1','Visible','on');
	bandpass_LayoutFcn(hObject);
	handles = guihandles(hObject);

	if (~isempty(varargin))
		x = varargin{1};			% Frequencies (not wavenumbers) are in 1/m
		if (x(1) > x(2)),		tmp = x(1);		x(1) = x(2);	x(2) = tmp;		end
		tr = (x(2) - x(1)) * 0.1;	% 10%
		LC = max(x(1) - tr/2, 0);			HP = max(x(2) - tr/2, 0);
		LP = min(x(1) + tr/2, x(2));		HC = x(2) + tr/2;
		set(handles.edit_LC, 'Str',1/HC),	set(handles.edit_LP, 'Str',1/HP)	% Revert because we are
		set(handles.edit_HC, 'Str',1/LP),	set(handles.edit_HP, 'Str',1/LC)	% displaying wavelength
	end
	
	handles.output = [];
	guidata(hObject, handles);
	
	% UIWAIT makes yes_or_no wait for user response (see UIRESUME)
	uiwait(handles.figure1);
	handles = guidata(hObject);
	if (nargout),		varargout{1} = handles.output;	end
	delete(handles.figure1)

% -------------------------------------------------------------------------
function edit_CB(hObject, handles)
	x = str2double(get(hObject,'String'));
	if (isnan(x) || x < 0),		set(hObject,'String',''),	return,		end

% -------------------------------------------------------------------------
function radio_freq_CB(hObject, handles)
	if (~get(hObject,'Value')),		set(hObject,'Value',1),	return,		end
	set(handles.radio_wave,'Val',0)

% -------------------------------------------------------------------------
function radio_wave_CB(hObject, handles)
	if (~get(hObject,'Value')),		set(hObject,'Value',1),	return,		end
	set(handles.radio_freq,'Val',0)

% -------------------------------------------------------------------------
function pushBP_OK_CB(hObject, handles)
% Band Pass
	LC = str2double(get(handles.edit_LC,'Str'));
	LP = str2double(get(handles.edit_LP,'Str'));
	HC = str2double(get(handles.edit_HC,'Str'));
	HP = str2double(get(handles.edit_HP,'Str'));
	
	msg = '';
	if (LC > LP),		msg = 'Low cut cannot be higher than Low pass';
	elseif (HC > HP),	msg = 'High cut cannot be higher than High pass';
	elseif (LP > HC),	msg = 'Low pass cannot be higher than High cut';
	end
	if (~isempty(msg)),	errordlg(msg, 'Error'),		return,		end
	
	if (get(handles.radio_wave, 'Val'))
		handles.output = 1 ./ [HP HC LP LC];	% The input to fft_stuff is frequency
	end
	guidata(handles.figure1, handles);
	uiresume(handles.figure1);

% --- Executes when user attempts to close figure1.
function BP_CloseRequestFcn(hObject, eventdata)
	handles = guidata(hObject);
	uiresume(handles.figure1);			% The GUI is still in UIWAIT

% --- Executes when user attempts to close figure1.
function BP_KeyPressFcn(hObject, eventdata)
	handles = guidata(hObject);
	uiresume(handles.figure1);		% The GUI is still in UIWAIT, us UIRESUME

% ------------------------------------------------------------------------
function bandpass_LayoutFcn(h1)

set(h1, 'Position',[520 679 350 121],...
'Color',get(0,'factoryUicontrolBackgroundColor'),...
'CloseRequestFcn', {@bandpass_uiCB,h1,'BP_CloseRequestFcn'},...
'KeyPressFcn',{@bandpass_uiCB,h1,'BP_KeyPressFcn'},...
'MenuBar','none',...
'Name','Bandpass',...
'NumberTitle','off',...
'Resize','off',...
'HandleVisibility','callback',...
'Tag','figure1');

uicontrol('Parent',h1, 'Position',[64 68 101 22],...
'BackgroundColor',[1 1 1],...
'Callback',{@bandpass_uiCB,h1,'edit_CB'},...
'Style','edit',...
'Tooltip','Low Cut frequency',...
'Tag','edit_LC');

uicontrol('Parent',h1, 'Position',[10 73 52 14],...
'FontName','Helvetica', 'HorizontalAlignment','right', 'String','Low cut','Style','text');

uicontrol('Parent',h1, 'Position',[64 38 101 22],...
'BackgroundColor',[1 1 1],...
'Callback',{@bandpass_uiCB,h1,'edit_CB'},...
'Style','edit',...
'Tooltip','Low Pass frequency',...
'Tag','edit_LP');

uicontrol('Parent',h1, 'Position',[1 43 60 14],...
'FontName','Helvetica', 'HorizontalAlignment','right','String','Low pass','Style','text');

uicontrol('Parent',h1, 'Position',[244 68 101 22],...
'BackgroundColor',[1 1 1],...
'Callback',{@bandpass_uiCB,h1,'edit_CB'},...
'Style','edit',...
'Tooltip','High Cut frequency',...
'Tag','edit_HC');

uicontrol('Parent',h1, 'Position',[190 73 52 14],...
'FontName','Helvetica', 'HorizontalAlignment','right','String','High cut','Style','text');

uicontrol('Parent',h1, 'Position',[244 38 101 22],...
'BackgroundColor',[1 1 1],...
'Callback',{@bandpass_uiCB,h1,'edit_CB'},...
'Style','edit',...
'Tooltip','High Pass frequency',...
'Tag','edit_HP');

uicontrol('Parent',h1, 'Position',[182 43 60 14],...
'FontName','Helvetica', 'HorizontalAlignment','right','String','High pass','Style','text');

uicontrol('Parent',h1, 'Position',[64 97 87 23],...
'Callback',{@bandpass_uiCB,h1,'radio_freq_CB'},...
'String','Frequency',...
'Style','radiobutton',...
'Tag','radio_freq');

uicontrol('Parent',h1, 'Position',[244 97 87 23],...
'Callback',{@bandpass_uiCB,h1,'radio_wave_CB'},...
'String','Wavelength',...
'Style','radiobutton',...
'Value',1,...
'Tag','radio_wave');

uicontrol('Parent',h1, 'Position',[264 7 80 21],...
'Callback',{@bandpass_uiCB,h1,'pushBP_OK_CB'},...
'FontSize',9,...
'FontWeight','bold',...
'String','OK',...
'Tag','pushBP_OK');

function bandpass_uiCB(hObject, eventdata, h1, callback_name)
% This function is executed by the callback and than the handles is allways updated.
	feval(callback_name,hObject,guidata(h1));

