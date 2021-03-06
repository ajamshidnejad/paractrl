function []=xsd_to_mo(XSD,folder_output,functionname)
% build an object factory from an xml schema

% generate acces point function
fid = fopen(fullfile(folder_output,[functionname '.m']),'wt');
fprintf(fid,['function [X]=' functionname '(name,opt)\n']);
writeout(fid,'%% autogenerated by xsd_to_mo\n\n');
writeout(fid,'if(nargin<2)\n')
writeout(fid,'\topt=false;\n')
writeout(fid,'end\n')
writeout(fid,'version=1;\n');
writeout(fid,'switch(version)\n');
for v=1:length(XSD)
    writeout(fid,sprintf('\tcase %d\n',v));
    writeout(fid,'\t\tif(opt)\n');
    writeout(fid,sprintf('\t\t\tX=%s_withopt_v%d(name);\n',functionname,v));
    writeout(fid,'\t\telse\n');
    writeout(fid,sprintf('\t\t\tX=%s_noopt_v%d(name);\n',functionname,v));
    writeout(fid,'\t\tend\n');
end
writeout(fid,'\totherwise\n');
writeout(fid,'\t\terror(''Unsupported version number'')\n');
writeout(fid,'end\n');
fclose(fid);
    

% process all xsd files
clear fid
for v=1:length(XSD)
    
    % initialize withopt file
    functionname_withopt = [functionname '_withopt_v' num2str(v)];
    fid(1) = fopen(fullfile(folder_output,[functionname_withopt '.m']),'wt');
    fprintf(fid(1),['function [X]=' functionname_withopt '(name)\n']);
    writeout(fid(1),'%% autogenerated by xsd_to_mo\n\n');
    
    % initialize noopt file
    functionname_noopt = [functionname '_noopt_v' num2str(v)];
    fid(2) = fopen(fullfile(folder_output,[functionname_noopt '.m']),'wt');
    fprintf(fid(2),['function [X]=' functionname_noopt '(name)\n']);
    writeout(fid(2),'%% autogenerated by xsd_to_mo\n\n');
    
    for i=1:length(XSD{v})
        xsd=xml_read(XSD{v}{i});
        writeit(xsd,fid(1),true,functionname_withopt)
        writeit(xsd,fid(2),false,functionname_noopt)
    end
    
    % close withopt
    writeout(fid(1),'error([name '' is not a supported model object''])')
    fclose(fid(1));
    
    % close noopt
    writeout(fid(2),'error([name '' is not a supported model object''])')
    fclose(fid(2));
    
    clear fid
    
end


% --------------------------------------------
function [str]=getAttribute(x,name)
if(isfield(x.ATTRIBUTE,name))
    str = x.ATTRIBUTE.(name);
else
    str = '';
end

% --------------------------------------------
function []=writeout(fids,str)
for i=1:length(fids)
    fprintf(fids(i),sprintf('%s',str));
end

% --------------------------------------------
function []=writeit(xsd,fid,include_opt,functionname)

if(isfield(xsd,'xs_COLON_element'))
    for i=1:length(xsd.xs_COLON_element)
        
        name = xsd.xs_COLON_element(i).ATTRIBUTE.name;
        ct = xsd.xs_COLON_element(i).xs_COLON_complexType;
        
        if(isfield(xsd.xs_COLON_element(i),'xs_COLON_simpleType'))
            st = xsd.xs_COLON_element(i).xs_COLON_simpleType;
        else
            st = [];
        end
        
        writeout(fid,sprintf('if(strcmp(name,''%s''))\n',name));
        
        if(~isempty(ct))
            process_complex_type(fid,ct,include_opt,functionname)
        end
        
        if(~isempty(st))
            writeout(fid,'\tX='''';\n');
        end
        
        % special case for 'shape'
        if(isempty(ct) && isempty(st))
            writeout(fid,'\tX='''';\n');
        end
        
        writeout(fid,sprintf('\treturn\n'));
        writeout(fid,sprintf('end\n\n'));
        
    end
end

if(isfield(xsd,'xs_COLON_complexType'))
    for i=1:length(xsd.xs_COLON_complexType)
        name = xsd.xs_COLON_complexType(i).ATTRIBUTE.name;
        writeout(fid,sprintf('if(strcmp(name,''%s''))\n',name));
        writeout(fid,sprintf('\tX=struct(...\n'));
        process_attribute( fid, ...
            xsd.xs_COLON_complexType(i).xs_COLON_attribute, ...
            include_opt, ...
            false);
        writeout(fid,sprintf('\t);\n'));
        writeout(fid,sprintf('return\n'));
        writeout(fid,sprintf('end\n\n'));
    end
end

if(isfield(xsd,'xs_COLON_simpleType'))
    for i=1:length(xsd.xs_COLON_simpleType)
        name = xsd.xs_COLON_simpleType(i).ATTRIBUTE.name;
        writeout(fid,sprintf('if(strcmp(name,''%s''))\n',name));
        writeout(fid,sprintf('\tX=[];\n'));
        writeout(fid,sprintf('return\n'));
        writeout(fid,sprintf('end\n\n'));
    end
end

% --------------------------------------------
function process_complex_type(fid,ct,include_opt,functionname)

has_all = isfield(ct,'xs_COLON_all');
has_sequence = isfield(ct,'xs_COLON_sequence');
has_attribute = isfield(ct,'xs_COLON_attribute');

wrotefirst_0 = false;

writeout(fid,'\tX = struct( ...\n');

% sequence (contain elements that have minOccur)
if(has_all)
    wrotefirst_0 = process_all( fid , ...
        ct.xs_COLON_all.xs_COLON_element, ...
        include_opt, ...
        functionname, ...
        wrotefirst_0);
end

% sequence (contain elements that have minOccur)
if(has_sequence)
    wrotefirst_0=process_sequence(fid , ...
        ct.xs_COLON_sequence.xs_COLON_element, ...
        include_opt, ...
        functionname, ...
        wrotefirst_0);
end

% attributes (could have use="optional") .....
if(has_attribute)
    process_attribute( fid, ...
        ct.xs_COLON_attribute, ...
        include_opt, ...
        wrotefirst_0);
end

writeout(fid,sprintf('\t);\n'));

% --------------------------------------------
function [wrotefirst_0]=process_all(fid,X,include_opt,functionname,wrotefirst_0)

for j=1:length(X)
    x = X(j);
    
    minOccurs = getAttribute(x,'minOccurs');
    if(isempty(minOccurs))
        minOccurs = 0;
    end
    if(~include_opt && minOccurs==0)
        continue
    end
    
    writeout(fid,'\t\t');
    if(wrotefirst_0)
        writeout(fid,',');
    end
    
    if(~isempty(getAttribute(x,'ref')))
        att_name = getAttribute(x,'ref');
        att_type = att_name;
    elseif(~isempty(getAttribute(x,'name')))
        att_name = getAttribute(x,'name');
        att_type = getAttribute(x,'type');
    else
        error('I need either a ref or a name')
    end
    
    % can erase this bit of code later
    if(~isempty( getAttribute(x,'ref')) && ~isempty(getAttribute(x,'name')))
        error('I expect either a ref or a name, but not both')
    end
    
    writeout(fid,sprintf('''%s'',%s(''%s'')...\n',att_name,functionname,att_type));
    
    wrotefirst_0 = true;
end

% --------------------------------------------
function [wrotefirst_0]=process_sequence(fid,X,include_opt,functionname,wrotefirst_0)

for j=1:length(X)
    x = X(j);
    
    minOccurs = getAttribute(x,'minOccurs');
    if(isempty(minOccurs))
        minOccurs = 0;
    end
    
    if(~include_opt && minOccurs==0)
        continue
    end
    
    writeout(fid,'\t\t');
    if(wrotefirst_0)
        writeout(fid,',');
    end
    
    if(~isempty(getAttribute(x,'ref')))
        att_name = getAttribute(x,'ref');
    elseif(~isempty(getAttribute(x,'name')))
        att_name = getAttribute(x,'name');
    else
        error('I need either a ref or a name')
    end
    
    % can erase this bit of code later
    if(~isempty( getAttribute(x,'ref')) && ~isempty(getAttribute(x,'name')))
        error('I expect either a ref or a name, but not both')
    end
    
    writeout(fid,sprintf('''%s'',%s(''%s'')...\n',att_name,functionname,att_name));
    
    wrotefirst_0 = true;
    
end

% --------------------------------------------
function [wrotefirst_0]=process_attribute(fid,X,include_opt,wrotefirst_0)

writeout(fid,'\t\t');
if(wrotefirst_0)
    writeout(fid,',');
end

writeout(fid,'''ATTRIBUTE'',struct(...\n');

wrotefirst_1 = false;

for j=1:length(X)
    x = X(j);
    
    if(~include_opt && strcmp(getAttribute(x,'use'),'optional'))
        continue
    end
    
    writeout(fid,'\t\t\t');
    if(wrotefirst_1)
        writeout(fid,',');
    end
    
    name = getAttribute(x,'name');
    writeout(fid,sprintf('''%s'',[]...\n',name));
    wrotefirst_1 = true;
    
end
writeout(fid,'\t\t\t)...\n');