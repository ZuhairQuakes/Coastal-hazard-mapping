function [selection,value] = choosebox(varargin)
%CHOOSEBOX  Two-listed item selection dialog box.
%   [SELECTION,OK] = CHOOSEBOX('ListString',S) creates a dialog box 
%   which allows you to select a string or multiple strings from a list.
%   Single or multiple strings can be transferred from a base list to a
%   selection list using an arrow-button. Single strings also can be
%   transferred by double-clicking; single or multiple strings are
%   transferred by pressing <CR>.
%   SELECTION is a vector of indices of the selected strings (length 1
%   in the single selection mode). The indices will be in the order of
%   selection from the base list. If a group of multiple strings is
%   selected, its order inside the group will not change, but different
%   groups are ordered by their selection. 
%   OK is 1 if you push the OK button, or 0 if you push the Cancel 
%   button or close the figure. In that case SELECTION will be [],
%   regardless to the actual selection list.
%   Important parameter is 'ChooseMode', see list below.
%
%   Inputs are in parameter,value pairs:
%
%   Parameter       Description
%   'ChooseMode'    string; can be 'pick' or 'copy'.
%                   When set to 'pick', transferred string items from the
%                   base list box are removed. When retransferred, they
%                   again are listed in their initial positions.
%                   When set to 'copy', transferred string items remain in
%                   the base list and can be transferred several times.
%                   default is 'pick'.
%   'ListString'    cell array of strings for the base list box.
%   'SelectionMode' string; can be 'single' or 'multiple'; defaults to
%                   'multiple'.
%   'ListSize'      [width height] of listbox in pixels; defaults to [160 300].
%                   If it has 3 elements the third is the percentage of how much left box is wider than right one.
%   'InitialValue'  vector of indices of which items of the list box
%                   are initially selected; defaults to none [].
%   'Name'          String for the figure's title. Defaults to ''.
%   'PromptString'  string matrix or cell array of strings which appears 
%                   as text above the base list box.  Defaults to {}.
%   'SelectString'  string matrix or cell array of strings which appears
%                   as text above the selection list box. Defaults to {}.
%	'multiple_finite'
%					a scalar with 0 meaning return only one pole (first selected) [DEFAULT]
%					any other value means return all selected poles.
%
%	'addpoles'		any value ~= 0, show only one confirmation button. Used to select TWO poles only
%
%   'uh'            uicontrol button height, in pixels; default = 18.
%   'fus'           frame/uicontrol spacing, in pixels; default = 8.
%   'ffs'           frame/figure spacing, in pixels; default = 8.
%
%   Example:
%     d = dir;
%     str = {d.name};
%     [s,v] = choosebox('Name','File deletion',...
%                     'PromptString','Files remaining in this directory:',...
%                     'SelectString','Files to delete:',...
%                     'ListString',str)
%
%   inspired by listdlg.m.
%
%   programmed by Peter Wasmeier, Technical University of Munich
%   p.wasmeier@bv.tum.de
%   11-12-03

%   Test:  d = dir;[s,v] = choosebox('Name','File deletion','PromptString','Files remaining in this directory:','SelectString','Files to delete:','ListString',{d.name});

%   As usual, hacked in many several ways to be used by Mirone. Joaquim Luis

% if (~length(varargin) == 2 & strcmp(varargin{1},'writeStages'))
%     doWriteStages(varargin{2})          % Poles were computes. Just write them and exit
%     return
% end

% $Id: choosebox.m 10217 2018-01-24 21:33:46Z j $

	mir_dirs = getappdata(0,'MIRONE_DIRS');
	if (~isempty(mir_dirs))
		ad.home_dir = mir_dirs.home_dir;		% Start in values
	else
		ad.home_dir = cd;
	end

	arrow = [...
	0     0     0     0     0     0     0     0     0     0     0     0     0     0     0     0     0
	0     1     1     1     1     1     1     1     1     1     1     1     1     1     1     1     0
	0     1     1     1     1     1     1     0     1     1     1     1     1     1     1     1     0
	0     1     1     1     1     1     1     0     0     1     1     1     1     1     1     1     0
	0     1     1     1     1     1     1     0     0     0     1     1     1     1     1     1     0
	0     1     1     1     1     1     1     0     0     0     0     1     1     1     1     1     0
	0     1     1     0     0     0     0     0     0     0     0     0     1     1     1     1     0
	0     1     1     0     0     0     0     0     0     0     0     0     0     1     1     1     0
	0     1     1     0     0     0     0     0     0     0     0     0     0     0     1     1     0
	0     1     1     0     0     0     0     0     0     0     0     0     0     1     1     1     0
	0     1     1     0     0     0     0     0     0     0     0     0     1     1     1     1     0
	0     1     1     1     1     1     1     0     0     0     0     1     1     1     1     1     0
	0     1     1     1     1     1     1     0     0     0     1     1     1     1     1     1     0
	0     1     1     1     1     1     1     0     0     1     1     1     1     1     1     1     0
	0     1     1     1     1     1     1     0     1     1     1     1     1     1     1     1     0
	0     1     1     1     1     1     1     1     1     1     1     1     1     1     1     1     0
	0     0     0     0     0     0     0     0     0     0     0     0     0     0     0     0     0];

	rarrow = repmat(arrow, [1 1 3]);
	larrow = repmat(fliplr(arrow), [1 1 3]);

	figname = '';
	smode = 2;   % (multiple)
	cmode = 1;   % remove from left hand side
	promptstring = {};
	selectstring = {};
	liststring = [];
	listsize = [160 300];
	initialvalue = [];
	addpoles = false;
	cancelstring = 'Cancel';
	fus = 8;
	ffs = 3;
	uh = 18;
	multiple_finite = 0;
	asym = 0;

if (mod(length(varargin),2) ~= 0)	% input args have not com in pairs
    error('Arguments to LISTDLG must come param/value in pairs.')
end
for (i = 1:2:numel(varargin))
	switch lower(varargin{i})
        case 'name'
            figname = varargin{i+1};
        case 'promptstring'
            promptstring = varargin{i+1};
        case 'selectstring'
            selectstring = varargin{i+1};
        case 'selectionmode'
            switch lower(varargin{i+1})
                case 'single',		smode = 1;
                case 'multiple',	smode = 2;
            end
        case 'choosemode'
            switch lower(varargin{i+1})
                case 'pick',		cmode = 1;
                case 'copy',		cmode = 2;
            end
        case 'listsize'
            listsize = varargin{i+1};
			if (numel(listsize) == 3)
				asym = listsize(3);
			end
        case 'liststring'
            liststring = varargin{i+1};
        case 'initialvalue'
            initialvalue = varargin{i+1};
        case 'uh'
            uh = varargin{i+1};
        case 'fus'
            fus = varargin{i+1};
        case 'ffs'
            ffs = varargin{i+1};
        case 'cancelstring'
            cancelstring = varargin{i+1};
        case 'multiple_finite'
            multiple_finite = varargin{i+1};
		case 'addpoles'
			addpoles = (varargin{i+1} ~= 0);
        otherwise
            error(['Unknown parameter name passed to LISTDLG.  Name was ' varargin{i}])
	end
end

if ischar(promptstring),	promptstring = cellstr(promptstring);	end
if ischar(selectstring),	selectstring = cellstr(selectstring);	end
if isempty(initialvalue),	initialvalue = 1;						end
if isempty(liststring),		error('ListString parameter is required.'),	end

ex = get(0,'defaultuicontrolfontsize')*1.7;		% height extent per line of uicontrol text (approx)

fp = get(0,'defaultfigureposition');
w = 4*fus + 2*ffs + 2*listsize(1) + 50;
h = 2*ffs + 7*fus + ex*length(promptstring) + listsize(2) + 2*uh;
fp = [fp(1) fp(2)+fp(4)-h w h];					% keep upper left corner fixed

if (asym)
	if (asym > 1),	asym = asym / 100;	end		% Assume percentage is in [0 100] instead of [0 1]
	asym = round(listsize(1) * asym);			% Convert asymetry percentage into pixel unites
end

fig = figure('name',figname, 'resize','off', 'numbertitle','off', 'visible','off', 'menubar','none', ...
    'position',fp, 'closerequestfcn','delete(gcbf)','Color',get(0,'factoryUicontrolBackgroundColor'));

ad.fromstring = cellstr(liststring);
ad.tostring = '';
ad.pos_left = (1:length(ad.fromstring))';
ad.pos_right = [];
ad.value = 0;
ad.cmode = cmode;
ad.hFig = fig;
ad.multiple_finite = multiple_finite;
setappdata(0,'ListDialogAppData',ad)

load([ad.home_dir filesep 'data' filesep 'mirone_icons.mat'],'Mfopen_ico','um_ico','dois_ico','help_ico',...
	'refrescaBA_ico','refrescaAB_ico','earthNorth_ico','earthSouth_ico','mais_ico','GE_ico');

h_toolbar = uitoolbar('parent',fig, 'BusyAction','queue','HandleVisibility','on',...
	'Interruptible','on','Tag','FigureToolBar','Visible','on');
uipushtool('parent',h_toolbar,'Click',@toggle_clicked_CB,'Tag','import',...
	'cdata',Mfopen_ico,'TooltipString','Open finite poles file');
uitoggletool('parent',h_toolbar,'cdata',dois_ico,'Tag','HalfAngle','Click',{@toggle_clicked_CB1,h_toolbar},...
	'Tooltip','Compute half angle stage poles','State','on');
uitoggletool('parent',h_toolbar,'cdata',um_ico,'Tag','FullAngle','Click',{@toggle_clicked_CB1,h_toolbar},...
	'Tooltip','Compute full angle stage poles');
uitoggletool('parent',h_toolbar,'cdata',refrescaBA_ico,'Tag','inverseStages','Click',{@toggle_clicked_CB2,h_toolbar},...
	'Tooltip','Rotations are with respect to the fixed plate A (A moves with respect to B)','Sep','on');
uitoggletool('parent',h_toolbar,'cdata',refrescaAB_ico,'Tag','directStages','Click',{@toggle_clicked_CB2,h_toolbar},...
	'Tooltip',sprintf('Rotations are with respect to the fixed plate B.\nThe plate A is where the points (isochrons) lies'), ...
	'State','on');
uitoggletool('parent',h_toolbar,'cdata',mais_ico,'Tag','positive','Click',{@toggle_clicked_CB3,h_toolbar},...
	'Tooltip','Reports positive rotation angles','State','on','Sep','on');
uitoggletool('parent',h_toolbar,'cdata',earthNorth_ico,'Tag','earthNorth','Click',{@toggle_clicked_CB3,h_toolbar},...
	'Tooltip','Place all output poles in the northern hemisphere');
uitoggletool('parent',h_toolbar,'cdata',earthSouth_ico,'Tag','earthSouth','Click',{@toggle_clicked_CB3,h_toolbar},...
	'Tooltip','Place all output poles in the southern hemisphere');
uipushtool('parent',h_toolbar,'cdata',GE_ico,'Click',@GE_clicked_CB,'Tooltip','Plot selected poles in GoogleEarth','Sep','on');
uipushtool('parent',h_toolbar,'Click',@GMT_clicked_CB,'Tooltip','Create a GMT script to plot poles');
uipushtool('parent',h_toolbar,'Click',@help_clicked_CB,'Tag','help','Tooltip','Help', 'cdata',help_ico,'Sep','on');

uicontrol('style','frame', 'position',[ffs ffs 2*fus+listsize(1)+asym 2*fus+uh])	% Frame for the Cancel button
uicontrol('style','frame', 'position',[ffs+2*fus+50+listsize(1)+asym ffs 2*fus+listsize(1)-asym 2*fus+uh])	% Frame for the 2 bottom buttons
uicontrol('style','frame', 'position',[ffs ffs+3*fus+uh 2*fus+listsize(1)+asym ...	% Frame for the left listbox
		listsize(2)+3*fus+ex*length(promptstring)+(uh+fus)*(smode==2)])
uicontrol('style','frame', 'position',[ffs+2*fus+50+listsize(1)+asym ffs+3*fus+uh 2*fus+listsize(1)-asym ...	% Frame for the right listbox
		listsize(2)+3*fus+ex*length(promptstring)+(uh+fus)*(smode==2)])

if ~isempty(promptstring)
		uicontrol('style','text','string',promptstring,...
			'horizontalalignment','left','units','pixels',...
			'position',[ffs+fus fp(4)-(ffs+fus+ex*length(promptstring)) ...
			listsize(1) ex*length(promptstring)]);
end
if ~isempty(selectstring)
	uicontrol('style','text','string',selectstring,...
			'horizontalalignment','left','units','pixels',...
			'position',[ffs+3*fus+listsize(1)+50+asym fp(4)-(ffs+fus+ex*length(promptstring)) ...
			listsize(1) ex*length(selectstring)]);
end

btn_wid = listsize(1)+asym;
btn_wid2 = listsize(1)/2;

uicontrol('style','listbox',...
		'position',[ffs+fus-5 ffs+uh+4*fus-5 listsize(1)+10+asym listsize(2)+30],...
		'string',ad.fromstring,...
		'backgroundcolor','w',...
		'max',2,...
		'FontName', 'FixedWidth',...
		'FontSize', 8, ...
		'Tag','leftbox',...
		'value',initialvalue, ...
		'callback',{@doFromboxClick});
         
uicontrol('style','listbox',...
		'position',[ffs+3*fus+listsize(1)+45+asym ffs+uh+4*fus-5 listsize(1)+10-asym listsize(2)+30],...
		'string',ad.tostring,...
		'backgroundcolor','w',...
		'max',2,...
		'FontName', 'FixedWidth',...
		'FontSize', 8, ...
		'Tag','rightbox',...
		'value',[], ...
		'callback',{@doToboxClick});

uicontrol('style','pushbutton',...
		'string',cancelstring,...
		'position',[ffs+fus ffs+fus btn_wid uh],...
		'callback',{@doCancel});

uicontrol('style','pushbutton',...
		'position',[ffs+2*fus+listsize(1)+10+asym ffs+uh+4*fus+(smode==2)*(fus+uh)+listsize(2)/2-25 30 30],...
		'cdata',rarrow,'callback',{@doRight});

uicontrol('style','pushbutton',...
		'position',[ffs+2*fus+listsize(1)+10+asym ffs+uh+4*fus+(smode==2)*(fus+uh)+listsize(2)/2+25 30 30],...
		'cdata',larrow,'callback',{@doLeft});

uicontrol('style','pushbutton', 'position',[ffs+2*fus+listsize(1)+3+asym 3 45 60],...
		'String','Filter','Tooltip','Filter the poles shown to those of a plate pair only.','callback',{@doFilter});

if (~addpoles)
	uicontrol('style','pushbutton', 'string','Finite Pole',...
			'position',[ffs+3*fus+btn_wid+50 ffs+fus btn_wid2-asym/2 uh],...
			'callback',{@doFinite});

	uicontrol('style','pushbutton', 'string','Compute Stage Poles',...
			'position',[ffs+3*fus+3*btn_wid2+50+asym/2 ffs+fus btn_wid2-asym/2 uh],...
			'callback',{@doStagePoles});
else
	uicontrol('style','pushbutton', 'string','Two poles to Add',...
			'position',[ffs+3*fus+btn_wid+50 ffs+fus btn_wid2*2-asym uh],...
			'callback',{@doFinite});
end

	%------------ Give a Pro look (3D) to the frame boxes  --------
	new_frame3D(fig, NaN)
	%------------- END Pro look (3D) ------------------------------

	try
		set(fig, 'visible','on');
		uiwait(fig);
	catch
		if ishandle(fig),	delete(fig),	end
	end

	if (isappdata(0,'ListDialogAppData') == 1)		% Selected Finite pole
		ad = getappdata(0,'ListDialogAppData');
		switch ad.value
			case 0
				selection = [];
			case 1
				selection = ad.pos_right;		% In fact it contains the finite pole [lon lat omega]
			case 2
				selection = ad.pos_right;		% In fact it contains the stage poles name
			case 3
				selection = ad.pos_right;		% In fact it contains finite poles (with ages)
		end
		value = ad.value;
		rmappdata(0,'ListDialogAppData')
	else
		% figure was deleted
		selection = [];
		value = 0;
	end

% --------------------------------------------------------------------
function toggle_clicked_CB(hObject, eventdata)
	ad = getappdata(0,'ListDialogAppData');
	aqui = cd;
	try		cd([ad.home_dir filesep 'continents']),		end
	[FileName,PathName] = uigetfile({'*.dat;*.DAT', 'poles files (*.dat,*.DAT)'},'Select finite poles File');
	pause(0.01)
	cd(aqui)
	if isequal(FileName,0);     return;     end

	% Read the file
	fid = fopen([PathName FileName],'rt');
	c = fread(fid,'*char').';
	fclose(fid);
	s = strread(c,'%s','delimiter','\n');

	ad.fromstring = s;
	set(findobj(ad.hFig,'Tag','leftbox'),'String',ad.fromstring);
	set(findobj(ad.hFig,'Tag','rightbox'),'String','');
	ad.tostring = '';
	ad.pos_left = (1:numel(ad.fromstring))';
	setappdata(0,'ListDialogAppData',ad)

% --------------------------------------------------------------------
function toggle_clicked_CB1(obj, eventdata, h_toolbar)
% Make sure that when one of the two uitoggletools is 'on' the other is 'off'
% First fish the two uitoggletool handles
	h2 = findobj(h_toolbar,'Tag','HalfAngle');
	h1 = findobj(h_toolbar,'Tag','FullAngle');
	% Now, find out which one of the above is the 'obj' (its one of them)
	if (h1 == obj),		h_that = h2;
	else				h_that = h1;
	end

	state = get(obj,'State');
	if (strcmp(state,'on')),	set(h_that,'State','off');
	else						set(h_that,'State','on');
	end

% --------------------------------------------------------------------
function toggle_clicked_CB2(obj, eventdata, h_toolbar)
% Make sure that when one of the two uitoggletools is 'on' the other is 'off'
% First fish the two uitoggletool handles
	h1 = findobj(h_toolbar,'Tag','inverseStages');
	h2 = findobj(h_toolbar,'Tag','directStages');
	% Now, find out which one of the above is the 'obj' (its one of them)
	if (h1 == obj),		h_that = h2;
	else				h_that = h1;
	end

	state = get(obj,'State');
	if (strcmp(state,'on')),	set(h_that,'State','off');
	else						set(h_that,'State','on');
	end

% --------------------------------------------------------------------
function toggle_clicked_CB3(obj, eventdata, h_toolbar)
% Make sure that when one of the three uitoggletools is 'on' the others are 'off'
% First fish the two uitoggletool handles
	h1 = findobj(h_toolbar,'Tag','earthNorth');
	h2 = findobj(h_toolbar,'Tag','earthSouth');
	h3 = findobj(h_toolbar,'Tag','positive');
	% Now, find out which one of the above is the 'obj' (its one of them)
	if (obj == h1)
		h_that = [h2 h3];
	elseif (obj == h2)
		h_that = [h1 h3];
	else
		h_that = [h1 h2];
	end

	state = get(obj,'State');
	if (strcmp(state,'on'))
		set(h_that,'State','off')
	else
		set(obj,'State','on')       % Clicked on the 'on' state. So keep it like that
	end

% --------------------------------------------------------------------------------------------------
function help_clicked_CB(obj,eventdata)
str = sprintf(['This tool allows you to compute stage poles from a list of finite rotation\n'...
		'poles. Alternatively, you can select only one finite pole from the list\n\n'...
		'By default an example list of finite rotations is loaded, but you can load\n'...
		'your own. The icons with "1" and "2" select if the full angle stage poles\n'...
		'are computed ("1") - useful for plate reconstructions, half angles ("2") -\n'...
		'useful for use in flow line drawing on a single plate.\n\n'...
		'The B<-A and A->B icons choose the fixed plate of the rotation. The point\n'...
		'is that the stage poles depend on which plate is used as reference (fixed\n',...
		'plate). We use the notation B_ROT_A to designate a finite rotation of\n',...
		'plate A with respect to plate B. Selecting the first option (B<-A) outputs\n',...
		'stages poles to be used for reconstructions on plate A, and vice-versa for\n',...
		'the second option (A->B).\n\n',...
		'Single or multiple poles can be transferred from a base list to the\n'...
		'selection list using an arrow-button. Single poles also can be transferred by double-clicking']);
helpdlg(str,'Help')

% --------------------------------------------------------------------------------------------------
function GE_clicked_CB(obj,evt)
	writekml(prepare_poles_struct('kml'))

% --------------------------------------------------------------------------------------------------
function GMT_clicked_CB(obj,evt)
	writeGMTscript(prepare_poles_struct('gmt'))

% --------------------------------------------------------------------------------------------------
function out = prepare_poles_struct(opt)
% Fetch the data and fill it in a structure. The structure members are different
% according to the OPT argument.
% OPT - 'kml' generates data expected by the writekml function
% OPT - 'gmt' puts the data in a way suitable for generating a GMT script

	ad = getappdata(0,'ListDialogAppData');
	rightbox = findobj(ad.hFig,'Tag','rightbox');
	selection = get(rightbox,'String');

	if (isempty(selection)),		return,		end

	n = numel(selection);
	finite = zeros(n,4);	names = cell(n,1);
	for (k = 1:n)					% Extract pole parameters from the cell array
		[tok,rem] = strtok(selection{k});		finite(k,1) = str2double(tok);
		[tok,rem] = strtok(rem);				finite(k,2) = str2double(tok);
		[tok,rem] = strtok(rem);				finite(k,3) = str2double(tok);
		[tok,rem] = strtok(rem);				finite(k,4) = str2double(tok);
		[tok,rem] = strtok(rem);
		tok = strtok(rem);
		names{k} = tok;
	end
	finite = sortrows(finite,4);				% To make sure they go from youngest to oldest
	
	% Fill the structure for either writekml or writeGMTscript
	if (strcmp(opt, 'kml'))
		out.nofig  = true;
		out.line.x = finite(:,1);		out.line.y = finite(:,2);
		out.pt.x   = finite(:,1);		out.pt.y   = finite(:,2);
		out.pt.str = names;
	else
		out.x   = finite(:,1);		out.y = finite(:,2);
		out.str = names;		
	end

% --------------------------------------------------------------------------------------------------
function writeGMTscript(in)
% Write a GMT script in $MIRONEROOT/tmp to plot the poles in an Orthographic projection
% Also display the commnads in a message window

	x_min = min(in.x);			x_max = max(in.x);
	x_c = (x_min + x_max) / 2;
	if (x_c > 360),		x_c = x_c - 360;	end
	% Convert to PS to get the BB and than convert back to geogs and build the -R option
	t = sprintf('-Js%.0f/90/1:1 -C -F', x_c);
	xy_ps = gmtmex(['mapproject -R-180/180/20/90 ' t], [in.x(:) in.y(:)]);
	mins = min(xy_ps.data);		maxs = max(xy_ps.data);
	corners_PS = [mins(1:2); maxs(1:2)];
	corners_g = gmtmex(['mapproject -R-180/180/20/90 -I ' t], corners_PS);
	ind = (corners_g.data(:,1) > 180);			% Want the [-180 180] interval
	corners_g.data(ind,1) = corners_g.data(ind,1) - 360;
	% And a little padding
	LLx = max(-180, corners_g.data(1,1)-1);		LLy = corners_g.data(1,2) - 0.5;
	URx = min(180, corners_g.data(2,1)-1);		URy = corners_g.data(2,2) + 0.5;
	opt_R = sprintf('-R%.0f/%.0f/%.0f/%.0fr', LLx, LLy, URx, URy);

	n_poles = numel(in.str);
	script_str = cell(n_poles*2 + 9, 1);
	if (ispc)
		script_str{1} = '@echo off';
		script_str{5} = sprintf('set ps=polos.ps');
		script_str{6} = sprintf('set font=+f10,5+jLB');
		script_str{7} = sprintf('set symb=-Sc0.2c -Gblack');
		fname = '%ps%';		font = '%font%';	symb = '%symb%';
		comm  = 'REM ';
	else
		script_str{1} = '#!/bin/bash';
		script_str{5} = sprintf('ps=polos.ps');
		script_str{6} = sprintf('font=+f10,5+jLB');
		script_str{7} = sprintf('symb=-Sc0.2c -Gblack');
		fname = '$ps';		font = '$font';	symb = '$symb';
		comm  = '# ';
	end
	script_str{2} = sprintf('%s Plot poles in Polar Stereographic projection', comm);
	script_str{3} = sprintf('%s Mirone Tech automatic script', comm);
	script_str{8} = sprintf('pscoast %s -JS%.0f/90/13c -Di -A5000 -G200 -W0.5p -Bag15 -BWSen -K -P > %s', ...
		opt_R, x_c, fname);
	for (k = 1:n_poles)
		script_str{k+8} = sprintf('echo %.2f %.2f | psxy -R -JS %s -fg -O -K >> %s', in.x(k), in.y(k), symb, fname);
		script_str{k+8+n_poles} = sprintf('echo %.2f %.2f | pstext -F%s+t%s -R -JS -fg -Dj0.1 -O -K >> %s', ...
			in.x(k), in.y(k), font, in.str{k}, fname);
	end
	script_str{end} = strrep(script_str{end}, '-K ', '');		% To close the PS file
	message_win('create',script_str,'figname','Poles script','edit','sim')

%-----------------------------------------------------------------------------------
function doCancel(varargin)
	ad.value = 0;
	ad.pos_right = [];
	setappdata(0,'ListDialogAppData',ad)
	delete(gcbf);

%-----------------------------------------------------------------------------------
function doFinite(varargin)
	rightbox = findobj('Tag','rightbox');
	selection = get(rightbox,'String');
	if (isempty(selection)),	return,	end		% If it's empty do nothing
	ad = getappdata(0,'ListDialogAppData');
	if (~ad.multiple_finite)					% Return only one pole (the first one)
		ad.value = 1;
		[tok,rem] = strtok(selection{1});		finite(1) = str2double(tok);
		[tok,rem] = strtok(rem);				finite(2) = str2double(tok);
		[tok,rem] = strtok(rem);				finite(3) = str2double(tok);
		tok = strtok(rem);						finite(4) = str2double(tok);
	else										% Return all selected poles (including its ages)
		ad.value = 3;
		finite = zeros(length(selection),4);
		for (i = 1:length(selection))
			[tok,rem] = strtok(selection{i});	finite(i,1) = str2double(tok);
			[tok,rem] = strtok(rem);			finite(i,2) = str2double(tok);
			[tok,rem] = strtok(rem);			finite(i,3) = str2double(tok);
			tok = strtok(rem);					finite(i,4) = str2double(tok);
		end
	end
	ad.pos_right = finite;
	setappdata(0,'ListDialogAppData',ad)
	delete(gcbf);

%-----------------------------------------------------------------------------------
function doStagePoles(varargin)
	ad = getappdata(0,'ListDialogAppData');
	rightbox = findobj(ad.hFig,'Tag','rightbox');
	selection = get(rightbox,'String');
	h1 = findobj(ad.hFig,'Tag','HalfAngle');
	h2 = findobj(ad.hFig,'Tag','inverseStages');
	h3 = findobj(ad.hFig,'Tag','earthNorth');
	if (strcmp(get(h1,'State'),'on'))			% See if full or half poles are requested
		half = 2;
	else
		half = 1;
	end
	if (strcmp(get(h2,'State'),'on'))			% See which stages are requested
		half = -half;
	end

	side = 1;									% Default to poles on the northern hemisphere
	if (strcmp(get(h3,'State'),'off'))			% See how to report the poles
		h4 = findobj(ad.hFig,'Tag','earthSouth');
		if (strcmp(get(h4,'State'),'on'))		% Place poles on the southern hemisphere
			side = -1;
		else									% Positive poles wanted
			side = 0;
		end
	end

	if (isempty(selection)),		return,		end

	n = length(selection);
	finite = zeros(n,4);
	for (k=1:n)					% Extract pole parameters from the cell array
		[tok,rem] = strtok(selection{k});		finite(k,1) = str2double(tok);
		[tok,rem] = strtok(rem);				finite(k,2) = str2double(tok);
		[tok,rem] = strtok(rem);				finite(k,3) = str2double(tok);
		tok = strtok(rem);						finite(k,4) = str2double(tok);
	end
	finite = sortrows(finite,4);				% To make sure they go from youngest to oldest

	% Convert latitudes to geocentric
	ecc = 0.0818191908426215;					% WGS84
	D2R = pi / 180;
	finite(:,2) = atan2( (1-ecc^2)*sin(finite(:,2)*D2R), cos(finite(:,2)*D2R) ) / D2R;

	stages = finite2stages(finite,half,side);	% Compute the Stage poles
	o{1} = sprintf('#longitude\tlatitude\ttstart(Ma)\ttend(Ma)\tangle(deg)');
	o{2} = sprintf('%9.5f\t%9.5f\t%8.4f\t%8.4f\t%7.4f\n', stages');
	message_win('create',o,'figname','Stage Poles','edit','sim')

% 	str1 = {'*.dat;*.stg', 'Data file (*.dat,*.stg)';'*.*', 'All Files (*.*)'};
% 	[FileName,PathName] = uiputfile(str1,'Stage poles file name');
% 	if isequal(FileName,0)		return,		end
% 	% Open and write to ASCII file
% 	if (ispc)			fid = fopen([PathName FileName],'wt');
% 	elseif (isunix)		fid = fopen([PathName FileName],'w');
% 	else				errordlg('Unknown platform.','Error');
% 	end
% 	fprintf(fid,'#longitude\tlatitude\ttstart(Ma)\ttend(Ma)\tangle(deg)\n');
% 	fprintf(fid,'%9.5f\t%9.5f\t%8.4f\t%8.4f\t%7.4f\n', stages');
% 	fclose(fid);
% 	ad.value = 2;
% 	setappdata(0,'ListDialogAppData',ad)

%-----------------------------------------------------------------------------------
function doWriteStages(stages)
% This function is called directly at the begining of choosebox,
% before the figure is even created
    str1 = {'*.dat;*.stg', 'Data file (*.dat,*.stg)';'*.*', 'All Files (*.*)'};
    [FileName,PathName] = uiputfile(str1,'Stage poles file name');
    if isequal(FileName,0);     return;     end
	%Open and write to ASCII file
	if ispc;        fid = fopen([PathName FileName],'wt');
	elseif isunix;  fid = fopen([PathName FileName],'w');
	else    errordlg('Unknown platform.','Error');
	end
	fprintf(fid,'#longitude\tlatitude\ttstart(Ma)\ttend(Ma)\tangle(deg)\n');
	fprintf(fid,'%9.5f\t%9.5f\t%8.4f\t%8.4f\t%7.4f\n', stages');
    fclose(fid);

%-----------------------------------------------------------------------------------
function doFromboxClick(varargin)
% if this is a doubleclick, doRight
	if strcmp(get(gcbf,'SelectionType'),'open'),	doRight;	end

%-----------------------------------------------------------------------------------
function doToboxClick(varargin)
% if this is a doubleclick, doLeft
	if strcmp(get(gcbf,'SelectionType'),'open'),	doLeft;		end

%-----------------------------------------------------------------------------------
function doRight(varargin)
	ad = getappdata(0,'ListDialogAppData');
	leftbox   = findobj(ad.hFig,'Tag','leftbox');
	rightbox  = findobj(ad.hFig,'Tag','rightbox');
	selection = get(leftbox,'Value');
	ad.pos_right = [ad.pos_right; ad.pos_left(selection)];
	ad.tostring = [ad.tostring; ad.fromstring(selection)];
	if (ad.cmode == 1)			% remove selected items
		ad.pos_left(selection) = [];
		ad.fromstring(selection) = [];
	end
	setappdata(0,'ListDialogAppData',ad)
	set(leftbox,'String',ad.fromstring,'Value',[]);
	set(rightbox,'String',ad.tostring,'Value',[]);

%-----------------------------------------------------------------------------------
function doLeft(varargin)
	ad = getappdata(0,'ListDialogAppData');
	leftbox = findobj(ad.hFig,'Tag','leftbox');
	rightbox = findobj(ad.hFig,'Tag','rightbox');
	selection = get(rightbox,'Value');
	if (ad.cmode == 1)      % if selected items had been removed
		% Sort in the items from right hand side again
		for i=1:length(selection)
			next_item = min( find(ad.pos_left > ad.pos_right(selection(i))) );
			if isempty(next_item)   % Inserting item is last one
				ad.pos_left(end+1)   = ad.pos_right(selection(i));
				ad.fromstring(end+1) = ad.tostring(selection(i));
			elseif (next_item == ad.pos_left(1))		% Inserting item is first one
				ad.pos_left=[ad.pos_right(selection(i));ad.pos_left];
				ad.fromstring=[ad.tostring(selection(i)); ad.fromstring];
			else                    % Inserting item is anywhere in the middle
				ad.pos_left=[ad.pos_left(1:next_item-1);ad.pos_right(selection(i));ad.pos_left(next_item:end)];
				ad.fromstring=[ad.fromstring(1:next_item-1); ad.tostring(selection(i)); ad.fromstring(next_item:end)];
			end
		end
	end
	ad.pos_right(selection) = [];
	ad.tostring(selection)  = [];
	setappdata(0,'ListDialogAppData',ad)
	set(leftbox,'String',ad.fromstring,'Value',[]);
	set(rightbox,'String',ad.tostring,'Value',[]);

%-----------------------------------------------------------------------------------
function doFilter(varargin)
	ad = getappdata(0,'ListDialogAppData');
	res = filtra_polos(ad.fromstring);
	if (isempty(res)),	return,		end
	ad.fromstring(~res) = [];
	h = findobj(ad.hFig, 'Tag', 'leftbox');
	set(h, 'String', ad.fromstring)
	h = findobj(ad.hFig, 'Tag', 'rightbox');
	set(h, 'String', '')

% --------------------------------------------------------
function R = make_rot_matrix (lonp, latp, w)
% lonp, latp	Euler pole in degrees
% w		angular rotation in degrees
% R		the rotation matrix

	D2R = pi / 180;
	[E0,E1,E2] = sph2cart(lonp*D2R,latp*D2R,1);

	sin_w = sin(w * D2R);
	cos_w = cos(w * D2R);
	c = 1 - cos_w;

	E_x = E0 * sin_w;
	E_y = E1 * sin_w;
	E_z = E2 * sin_w;
	E_12c = E0 * E1 * c;
	E_13c = E0 * E2 * c;
	E_23c = E1 * E2 * c;

	R(1,1) = E0 * E0 * c + cos_w;
	R(1,2) = E_12c - E_z;
	R(1,3) = E_13c + E_y;

	R(2,1) = E_12c + E_z;
	R(2,2) = E1 * E1 * c + cos_w;
	R(2,3) = E_23c - E_x;

	R(3,1) = E_13c - E_y;
	R(3,2) = E_23c + E_x;
	R(3,3) = E2 * E2 * c + cos_w;

% --------------------------------------------------------
function [plon,plat,w] = matrix_to_pole (T,side)

	R2D = 180 / pi;
	T13_m_T31 = T(1,3) - T(3,1);
	T32_m_T23 = T(3,2) - T(2,3);
	T21_m_T12 = T(2,1) - T(1,2);
	H = T32_m_T23 * T32_m_T23 + T13_m_T31 * T13_m_T31;
	L = sqrt (H + T21_m_T12 * T21_m_T12);
	H = sqrt (H);
	tr = T(1,1) + T(2,2) + T(3,3);

	plon = atan2(T13_m_T31, T32_m_T23) * R2D;
	%if (plon < 0)     plon = plon + 360;  end
	plat = atan2(T21_m_T12, H) * R2D;
	w = atan2(L, (tr - 1)) * R2D;

	if ((side == 1 && plat < 0) || (side == -1 && plat > 0))
		plat = -plat;
		plon = plon + 180;
		if (plon > 360),    plon = plon - 360;  end
		w = -w;
	end

% --------------------------------------------------------------------------------
function output = filtra_polos(varargin)
% Helper window to pick only poles that fit to a certain pattern in their names

	hObject = figure('Vis','on');
	filtra_polos_LayoutFcn(hObject);
	handles = guihandles(hObject);
	move2side(hObject,'right')

	handles.list = varargin{1};
	handles.output = '';
	guidata(hObject, handles);

	ind = strfind(handles.list, '!');
	tmp = cell(numel(ind),1);
	for (k = 1:numel(ind))
		tmp{k} = strtok(handles.list{k}(ind{k}+1:end));
	end
	tmp = unique(tmp);
	if (isempty(tmp{1})),	tmp(1) = [];	end
	set(handles.popup_pairs, 'Str', tmp)
	
	uiwait(handles.figure1);
	handles = guidata(hObject);
	output = handles.output;
	delete(handles.figure1);

% -------------------------------------------------------------------------------------------
function popup_pairs_CB(hObject, handles)
	contents = get(hObject,'String');
	txt = contents{get(hObject,'Value')};
	set(handles.edit_whichPair, 'Str', txt)

% -------------------------------------------------------------------------------------------
function push_OK_CB(hObject, handles)
% ...
	t = get(handles.edit_whichPair, 'Str');
	c = false(numel(handles.list),1);
	for (k = 1:numel(handles.list))
		if (strfind(handles.list{k}, t))
			c(k) = true;
		end
	end
	handles.output = c;
	guidata(handles.figure1, handles)
	uiresume(handles.figure1);

% -------------------------------------------------------------------------------------------
function figure1_CloseRequestFcn(hObject, evt)
	handles = guidata(hObject);
	do_uiresume = strcmp(get(handles.figure1, 'waitstatus'), 'waiting');
	if (do_uiresume)		% The GUI is still in UIWAIT, us UIRESUME
		uiresume(handles.figure1);
	else					% The GUI is no longer waiting, just close it
		delete(handles.figure1);
	end

% --- Creates and returns a handle to the GUI figure. 
function filtra_polos_LayoutFcn(h1)
	set(h1, 'Pos',[520 734 191 70],...
		'Color',get(0,'factoryUicontrolBackgroundColor'),...
		'CloseRequestFcn', @figure1_CloseRequestFcn,...
		'MenuBar','none',...
		'Name','Filter poles',...
		'NumberTitle','off',...
		'Resize','off',...
		'HandleVisibility','callback',...
		'Tag','figure1');

	uicontrol('Parent',h1, 'Position',[10 39 91 21], 'BackgroundColor',[1 1 1],...
		'Callback',@filtra_polos_uiCB,...
		'Style','popupmenu', 'String', ' ',...
		'Tag','popup_pairs');

	uicontrol('Parent',h1, 'Position',[110 39 80 21], 'BackgroundColor',[1 1 1],...
		'Style','edit',...
		'TooltipString','Enter a single plate acronym to select all poles involving this plate.',...
		'Tag','edit_whichPair');

	uicontrol('Parent',h1, 'Position',[110 8 80 22],...
		'Callback',@filtra_polos_uiCB,...
		'FontSize',9,...
		'FontWeight','bold',...
		'String','OK',...
		'Tag','push_OK');

function filtra_polos_uiCB(hObject, eventdata)
% This function is executed by the callback and than the handles is allways updated.
	feval([get(hObject,'Tag') '_CB'],hObject, guidata(hObject));