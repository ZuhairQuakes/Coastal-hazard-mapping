function varargout = vector_project(varargin)
%
%
%	Copyright (c) 2004-2011 by J. Luis
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

	hObject = figure('Vis','off');
	vector_project_LayoutFcn(hObject);
	handles = guihandles(hObject);
	move2side(hObject,'right')

	% Set the default projections ofered here
	handles.prjName = {''; 'EPSG:4326 - long/lat:WGS84'; ...
		'UTM29'; ...
		'EPSG:20790 - Hayford-Gauss Datum Lisboa (Militar)'; ...
		'EPSG:20791 - Hayford-Gauss Datum Lisboa'; ...
		'EPSG:27493 - Hayford-Gauss Datum 73'; ...
		'EPSG:3763 - ETRS89 / Portugal TM06'; ...
		'EPSG:4207 - Geogr�ficas Datum Lisboa'; ...
		'EPSG:4274 - Geogr�ficas Datum 73'; ...
		'ED50 - '; ...
		'BaseSE - PTRA08-UTM28/ITRF93'; ...
		'BaseSW - PTRA08-UTM26/ITRF93'; ...
		'SBraz - PTRA08-UTM26/ITRF93'; ...
		'Observatorio - PTRA08-UTM25/ITRF93'; ...
		'EPSG:     - Web Mercator'; ...
		'Lambert Conformal Conic'; ...
		'Lambert Equal Area'; ...
		'Polar Stereographic' ...
		};
	
	handles.prjPROJ4 = {''; '+proj=latlong +ellps=wgs84 +no_defs'; ...
		'+proj=utm +zone=29 +k=0.9996 +ellps=grs80 +towgs84=0,0,0'; ...
		'+proj=tmerc +lat_0=39.666666666666667 +lon_0=-8.131906111111111 +k=1 +x_0=200000 +y_0=300000 +ellps=intl +towgs84=-304.046,-60.576,103.640,0,0,0,0'; ...
		'+proj=tmerc +lat_0=39.666666666666667 +lon_0=-8.131906111111111 +k=1 +x_0=0 +y_0=0 +ellps=intl +towgs84=-283.088,-70.693,117.445,-1.157,0.059,-0.652,-4.058'; ...
		'+proj=tmerc +lat_0=39.666666666666667 +lon_0=-8.131906111111111 +k=1 +x_0=180.598 +y_0=-86.98999999999999 +ellps=intl +towgs84=-230.994,102.591,25.199,0.633,-0.239,0.9,1.95'; ...
		'+proj=tmerc +lat_0=39.668258333333333 +lon_0=-8.133108333333333 +k=1 +x_0=0 +y_0=0 +ellps=GRS80 +units=m +no_defs +towgs84=0,0,0'; ...
		'+proj=longlat +ellps=intl +no_defs'; ...
		'+proj=longlat +ellps=intl +no_defs'; ...
		'+proj=utm +zone=29 +k=0.9996 +ellps=intl +towgs84=-85.858,-108.681,-120.361,0,0,0,0'; ...		% ED50
		'+proj=utm +zone=28 +k=0.9996 +ellps=intl +towgs84=-160.41,-21.066,-99.282,2.437,-17.25,-7.446,0.168 +units=m +no_defs'; ...% Base SE - Porto Santo
		'+proj=utm +zone=26 +k=0.9996 +ellps=intl +towgs84=-185.391,122.266,35.989,0.12,3.18,2.046,-1.053 +units=m +no_defs'; ...	% Base SW - Graciosa (Grupo Central do Arquip�lago dos A�ores)
		'+proj=utm +zone=26 +k=0.9996 +ellps=intl +towgs84=-269.089,186.247,155.667,2.005,3.606,-0.366,0.097 +units=m +no_defs'; ...% S. Miguel (Grupo Oriental do Arquip�lago dos A�ores)
		'+proj=utm +zone=25 +k=0.9996 +ellps=intl +towgs84=-487.978,-226.275,102.787,-0.743,1.677,2.087,1.485 +units=m +no_defs'; ...% Flores (Grupo Ocidental do Arquip�lago dos A�ores)
		'+proj=merc +lon_0=0 +k=1 +x_0=0 +y_0=0 +a=6378137 +b=6378137 +units=m +no_defs'; ...			% Web Mercator
		'+proj=lcc +lat_1=20n +lat_2=60n'; ...				% Lambert Conformal Conic
		'+proj=laea +lat_1=20n +lat_2=60n'; ...				% Lambert Equal Area
		'+proj=stere +lat_ts=71 +lat_0=90 +lon_0=0' ...		% Polar Stereographic
		};

	handles.fileDataLeft = [];
	handles.projStruc.SrcProjWKT = [];
	handles.projStruc.DstProjWKT = [];
	mir_dirs = getappdata(0,'MIRONE_DIRS');
	if (~isempty(mir_dirs))
		handles.last_dir = mir_dirs.last_dir;
		handles.home_dir = mir_dirs.home_dir;
		handles.work_dir = mir_dirs.work_dir;
	else
		handles.last_dir = cd;
		handles.home_dir = handles.last_dir;
		handles.work_dir = handles.last_dir;
	end

	set([handles.popup_sourceSRS handles.popup_destSRS],'String',handles.prjName)

	%------------ Give a Pro look (3D) to the frame boxes  -------------------------------
	new_frame3D(hObject, [handles.text_In handles.text_Out]);
	%------------- END Pro look (3D) -----------------------------------------------------

	% ------------------ TABPANEL SECTION ----------------------------------------
	% This is the tag that all tab push buttons share.  If you have multiple
	% sets of tab push buttons, each group should have unique tag.
	group_name = 'tab_group';

	% This is a list of the UserData values used to link tab push buttons and the
	% components on their linked panels. To add a new tab panel to the group
	%  Add the button using GUIDE
	%  Assign the Tag based on the group name - in this case tab_group
	%  Give the UserData a unique name - e.g. another_tab_panel
	%  Add components to GUIDE for the new panel
	%  Give the new components the same UserData as the tab button
	%  Add the new UserData name to the below cell array
	panel_names = {'interactive','FileConv'};

	% tabpanelfcn('makegroups',...) adds new fields to the handles structure,
	% one for each panel name and another called 'group_name_all'.  These fields
	% are used by the tabpanefcn when tab_group_handler is called.
	handles = tabpanelfcn('make_groups',group_name, panel_names, handles, 1);
	% ------------------------------------------------------------------------------

	guidata(hObject, handles);
	set(hObject,'Visible','on','HandleVisibility','callback');
	if (nargout),   varargout{1} = hObject;     end

% -----------------------------------------------------------------------------------------
function tab_group_CB(hObject, handles)
    handles = tabpanelfcn('tab_group_handler',hObject, handles, get(hObject, 'Tag'));
    guidata(handles.figure1, handles)

% -----------------------------------------------------------------------------------------
function popup_sourceSRS_CB(hObject, handles)
% Get Source SRS and put its Proj4 string in the companion edit box
	val = get(hObject,'Val');
	if (val == 1)			% Empty
		set(handles.edit_prjSource, 'Str', '', 'BackgroundColor',[1 1 1])
		handles.projStruc.SrcProjWKT = [];
		guidata(handles.figure1, handles);
	else
		set(handles.edit_prjSource, 'Str', handles.prjPROJ4{val})
		edit_prjSource_CB(handles.edit_prjSource, handles)
	end

% -----------------------------------------------------------------------------------------
function edit_prjSource_CB(hObject, handles)
	s_srs = get(hObject, 'Str');
	try
		handles.projStruc.SrcProjWKT = ogrproj(s_srs);
		set(hObject,'BackgroundColor',[1 1 1])
	catch
		handles.projStruc.SrcProjWKT = [];
		set(hObject,'BackgroundColor',[255 204 204]/255)
	end
	guidata(handles.figure1, handles);

% -----------------------------------------------------------------------------------------
function popup_destSRS_CB(hObject, handles)
% Get Target SRS and put its Proj4 string in the companion edit box
	val = get(hObject,'Val');
	if (val == 1)			% Empty
		set(handles.edit_prjDestiny, 'Str', '', 'BackgroundColor',[1 1 1])
		handles.projStruc.DstProjWKT = [];
		guidata(handles.figure1, handles);
	else
		set(handles.edit_prjDestiny, 'Str', handles.prjPROJ4{val})
		edit_prjDestiny_CB(handles.edit_prjDestiny, handles)
	end

% -----------------------------------------------------------------------------------------
function edit_prjDestiny_CB(hObject, handles)
	t_srs = get(handles.edit_prjDestiny,'Str');
	try
		handles.projStruc.DstProjWKT = ogrproj(t_srs);
		set(hObject,'BackgroundColor',[1 1 1])
	catch
		handles.projStruc.DstProjWKT = [];
		set(hObject,'BackgroundColor',[255 204 204]/255)
	end
	guidata(handles.figure1, handles);

% -----------------------------------------------------------------------------------------
function edit_fileLeft_CB(hObject, handles)
% Read the input file
	fname = get(hObject, 'Str');
	if (exist(fname, 'file') == 2)
		errordlg('Error: file does not exist','Error')
		set(hObject, 'Str', '')
		handles.fileDataLeft = [];		% Reset, just in case it had something already
	else
		out = load_xyz([], fname);
		if (isempty(out)),		set(hObject, 'Str', ''),		end
		handles.fileDataLeft = out;
	end
	guidata(handles.figure1, handles)
	
% -----------------------------------------------------------------------------------------
function push_fileLeft_CB(hObject, handles)
% Get file name of the to-be-projected file
	[FileName,PathName,handles] = put_or_get_file(handles,{'*.dat;*.DAT', 'Mag file (*.dat,*.DAT)';'*.*', 'All Files (*.*)'},'Select data file','get');
	if (isequal(FileName,0))
		set(handles.edit_fileLeft,'String',''),		return
	end
	fname = [PathName FileName];
	set(handles.edit_fileLeft,'String',fname)
	edit_fileLeft_CB(handles.edit_fileLeft, handles)		% Let it do the rest of the work

% -----------------------------------------------------------------------------------------
function push_fileRight_CB(hObject, handles)
% Get file name of the projected file
	[FileName,PathName,handles] = put_or_get_file(handles,{'*.dat;*.DAT', 'Mag file (*.dat,*.DAT)';'*.*', 'All Files (*.*)'},'Select data file','put');
	if (isequal(FileName,0))
		set(handles.edit_fileRight,'String',''),		return
	end
	fname = [PathName FileName];
	set(handles.edit_fileRight,'String',fname)

% -----------------------------------------------------------------------------------------
function popup_sourceFormat_CB(hObject, handles)


% -----------------------------------------------------------------------------------------
function popup_destinyFormat_CB(hObject, handles)


% -----------------------------------------------------------------------------------------
function out = push_OK_CB(hObject, handles)
% ...
	
	if ( isempty(handles.projStruc.SrcProjWKT) || isempty(handles.projStruc.DstProjWKT) )
		errordlg('Invalid Source or Destiny projection string.','Error'),	return
	end

	if ( strcmp(get(handles.edit_xLeft,'Vis'), 'on') )		% Point conversions
		x = str2double(get(handles.edit_xLeft, 'Str'));
		y = str2double(get(handles.edit_yLeft, 'Str'));
		z = str2double(get(handles.edit_zLeft, 'Str'));
		if (isnan(z)),		z = [];		end

		xy_prj = ogrproj([x y z], handles.projStruc);
		if (nargout)
			out = xy_prj;
		else
			set(handles.edit_xRight, 'Str', num2str(xy_prj(1)))
			set(handles.edit_yRight, 'Str', num2str(xy_prj(2)))
			if (numel(xy_prj) == 3),	set(handles.edit_zRight, 'Str', num2str(xy_prj(3))),	end
		end
	else
		if (isempty(handles.fileDataLeft)),		return,		end
		fname = get(handles.edit_fileRight, 'Str');
		if (isempty(fname))
			errordlg('Need to know the output file name','Error'),	return
		end

		if (~isa(handles.fileDataLeft, 'cell'))
			xy_prj = ogrproj(handles.fileDataLeft, handles.projStruc);
			if (nargout),		out = xy_prj;
			else				double2ascii(fname,xy_prj);
			end
		else
			xy_prj = cell(numel(handles.fileDataLeft), 1);
			for (k = 1:numel(handles.fileDataLeft))
				xy_prj{k} = ogrproj(handles.fileDataLeft{k}, handles.projStruc);
			end
			if (nargout),		out = xy_prj;
			else				double2ascii(fname,xy_prj,'%f','maybeMultis');
			end
		end
	end

% --- Creates and returns a handle to the GUI figure. 
function vector_project_LayoutFcn(h1)

set(h1, 'Position',[520 459 620 341],...
'Color',get(0,'factoryUicontrolBackgroundColor'),...
'MenuBar','none',...
'Name','Point project',...
'NumberTitle','off',...
'Resize','off',...
'Tag','figure1');

uicontrol('Parent',h1,...
'Call',@vec_proj_uiCB,...
'Position',[10 128 151 23],...
'String','Interactive conversions',...
'UserData','interactive',...
'Tag','tab_group');

uicontrol('Parent',h1,...
'Call',@vec_proj_uiCB,...
'Position',[162 128 130 23],...
'String','File conversions',...
'UserData','FileConv',...
'Tag','tab_group');

uicontrol('Parent',h1, 'Position',[10 29 602 101],...
'Enable','inactive',...
'Tag','push_tab_bg');

uicontrol('Parent',h1, 'Position',[318 34 286 89], 'Style','frame');
uicontrol('Parent',h1, 'Position',[17 34 288 89], 'Style','frame');

uicontrol('Parent',h1,...
'FontSize',10,...
'Position',[10 312 85 16],...
'String','Source SRS:',...
'Style','text');

uicontrol('Parent',h1,...
'FontSize',10,...
'Position',[9 222 90 16],...
'String','Destiny SRS:',...
'Style','text');

uicontrol('Parent',h1,...
'BackgroundColor',[1 1 1],...
'HorizontalAlignment','left',...
'Position',[325 72 250 22],...
'Style','edit',...
'UserData','FileConv',...
'Tag','edit_fileRight');

uicontrol('Parent',h1,...
'BackgroundColor',[1 1 1],...
'Call',@vec_proj_uiCB,...
'HorizontalAlignment','left',...
'Position',[25 72 250 22],...
'Style','edit',...
'UserData','FileConv',...
'Tag','edit_fileLeft');

uicontrol('Parent',h1,...
'BackgroundColor',[1 1 1],...
'Call',@vec_proj_uiCB,...
'HorizontalAlignment','left',...
'Max',3,...
'Position',[10 260 601 41],...
'Style','edit',...
'TooltipString','PROJ4 string describing the source referencing system',...
'Tag','edit_prjSource');

uicontrol('Parent',h1,...
'BackgroundColor',[1 1 1],...
'Call',@vec_proj_uiCB,...
'HorizontalAlignment','left',...
'Max',3,...
'Position',[10 170 601 41],...
'Style','edit',...
'Tooltip','PROJ4 string describing the destination referencing system',...
'Tag','edit_prjDestiny');

uicontrol('Parent',h1,...
'BackgroundColor',[1 1 1],...
'Call',@vec_proj_uiCB,...
'Position',[100 309 321 22],...
'String','EPSG:20791 - Hayford-Gauss Datum Lisboa',...
'Style','popupmenu',...
'Value',1,...
'Tag','popup_sourceSRS');

uicontrol('Parent',h1,...
'BackgroundColor',[1 1 1],...
'Call',@vec_proj_uiCB,...
'Position',[99 219 321 22],...
'String','EPSG:20791 - Hayford-Gauss Datum Lisboa',...
'Style','popupmenu',...
'Value',1,...
'Tag','popup_destSRS');

uicontrol('Parent',h1,...
'BackgroundColor',[1 1 1],...
'HorizontalAlignment','left',...
'Position',[96 94 140 22],...
'Style','edit',...
'UserData','interactive',...
'Tag','edit_xLeft');

uicontrol('Parent',h1,...
'FontSize',9,...
'HorizontalAlignment','right',...
'Position',[23 98 72 16],...
'String','Longitude/X ',...
'Style','text',...
'UserData','interactive',...
'Tag','text_xLeft');

uicontrol('Parent',h1,...
'BackgroundColor',[1 1 1],...
'HorizontalAlignment','left',...
'Position',[96 67 140 22],...
'Style','edit',...
'UserData','interactive',...
'Tag','edit_yLeft');

uicontrol('Parent',h1,...
'FontSize',9,...
'HorizontalAlignment','right',...
'Position',[23 71 72 16],...
'String','Latitude/Y ',...
'Style','text',...
'UserData','interactive',...
'Tag','text_yLeft');

uicontrol('Parent',h1,...
'BackgroundColor',[1 1 1],...
'HorizontalAlignment','left',...
'Position',[96 40 140 22],...
'Style','edit',...
'UserData','interactive',...
'Tag','edit_zLeft');

uicontrol('Parent',h1,...
'FontSize',9,...
'HorizontalAlignment','right',...
'Position',[48 44 47 16],...
'String','Height ',...
'Style','text',...
'UserData','interactive',...
'Tag','text_zLeft');

uicontrol('Parent',h1,...
'BackgroundColor',[1 1 1],...
'HorizontalAlignment','left',...
'Position',[408 94 140 22],...
'Style','edit',...
'UserData','interactive',...
'Tag','edit_xRight');

uicontrol('Parent',h1,...
'FontSize',9,...
'HorizontalAlignment','right',...
'Position',[335 98 72 16],...
'String','Longitude/X ',...
'Style','text',...
'UserData','interactive',...
'Tag','text_xRight');

uicontrol('Parent',h1,...
'BackgroundColor',[1 1 1],...
'HorizontalAlignment','left',...
'Position',[408 67 140 22],...
'Style','edit',...
'UserData','interactive',...
'Tag','edit_yRight');

uicontrol('Parent',h1,...
'FontSize',9,...
'HorizontalAlignment','right',...
'Position',[335 71 72 16],...
'String','Latitude/Y ',...
'Style','text',...
'UserData','interactive',...
'Tag','text_yRight');

uicontrol('Parent',h1,...
'BackgroundColor',[1 1 1],...
'HorizontalAlignment','left',...
'Position',[408 40 140 22],...
'Style','edit',...
'UserData','interactive',...
'Tag','edit_zRight');

uicontrol('Parent',h1,...
'FontSize',9,...
'HorizontalAlignment','right',...
'Position',[360 44 47 16],...
'String','Height ',...
'Style','text',...
'UserData','interactive',...
'Tag','text_zRight');

% uicontrol('Parent',h1,...
% 'BackgroundColor',[1 1 1],...
% 'Call',@vec_proj_uiCB,...
% 'Position',[490 311 110 20],...
% 'String',{'DD.xxxxxx'; 'DD.MM'; 'DD.MM.xxxx'; 'DD.MM.SS'; 'DD.MM.SS.xx'},...
% 'Style','popupmenu',...
% 'Value',1,...
% 'Tag','popup_sourceFormat');
% 
% uicontrol('Parent',h1,...
% 'BackgroundColor',[1 1 1],...
% 'Call',@vec_proj_uiCB,...
% 'Position',[490 221 110 20],...
% 'String',{'meters'; 'kilometers'},...
% 'Style','popupmenu',...
% 'Value',1,...
% 'Tag','popup_destinyFormat');

uicontrol('Parent',h1,...
'Position',[26 41 200 17],...
'String','Ellipsoidal heights in third column?',...
'Style','checkbox',...
'UserData','FileConv',...
'Tag','check_ellipHeight');

uicontrol('Parent',h1,...
'Call',@vec_proj_uiCB,...
'Position',[274 72 23 23],...
'String','...',...
'UserData','FileConv',...
'Tag','push_fileLeft');

uicontrol('Parent',h1,...
'Call',@vec_proj_uiCB,...
'Position',[574 72 23 23],...
'String','...',...
'UserData','FileConv',...
'Tag','push_fileRight');

uicontrol('Parent',h1,...
'Call',@vec_proj_uiCB,...
'FontSize',10,...
'FontWeight','bold',...
'Position',[512 5 100 21],...
'String','Compute',...
'Tag','push_OK');

uicontrol('Parent',h1,...
'FontAngle','oblique',...
'FontWeight','bold',...
'ForegroundColor',[0 0 0.6274509804],...
'Position',[247 112 51 15],...
'String','Input',...
'Style','text',...
'Tag','text_In');

uicontrol('Parent',h1,...
'FontAngle','oblique',...
'FontWeight','bold',...
'ForegroundColor',[0 0 0.6274509804],...
'Position',[549 112 51 15],...
'String','Output',...
'Style','text',...
'Tag','text_Out');

function vec_proj_uiCB(hObject, eventdata)
% This function is executed by the callback and than the handles is allways updated.
	feval([get(hObject,'Tag') '_CB'],hObject, guidata(hObject));
