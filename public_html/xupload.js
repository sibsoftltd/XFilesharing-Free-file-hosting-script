var show_fname_chars=50;
var UID,NF=0,cx=0,slots=1,fnames;

function $(elem){return document.getElementById(elem);}

function openStatusWindow(f1)
{ 
 var cgi_url = form_action.split('upload.cgi')[0]+'upload_status.cgi';
 var url = cgi_url+'?uid='+UID+'&files='+fnames+'&ok=1';

 xy = findPos( $('div1') );
 $('progress2').style.left = xy[0]+'px';
 $('progress2').style.top = xy[1]+'px';
 $('progress2f').style.width = $('div1').clientWidth + 'px';
 $('progress2f').style.height = $('div1').clientHeight + 'px';

 $('div1').style.visibility='hidden';

 self.transfer2.document.location = url;
}

function generateSID(f1)
{
 UID='';
 for(var i=0;i<12;i++)UID+=''+Math.floor(Math.random() * 10);
}

function StartUpload(f1)
{
    NF=0;
    f1.target='xupload';

    for (var i=0;i<f1.length;i++)
    {
     current = f1.elements[i];
     if(current.type=='file' && current.value!='')
      {
         if(!checkExt(current))return false;
         NF++;
      }
    }
    cx=0;
    fnames='';
    for (var i=0;i<=f1.length;i++)
    {
      current = f1[i];
      if(current && current.type && current.type=='file')
      {
         var descr = $(current.name+'_descr');
         if(descr)descr.name = 'file_'+cx+'_descr';
         current.name = 'file_'+cx;
         cx++;
         name = current.value.match(/[^\\\/]+$/);
         if(name && name!='null')fnames+=':'+name;
      }
    }

    if(NF==0){alert('Select at least one file to upload');return false;};
    if(f1.tos && !f1.tos.checked){alert('You should read and agree to the Terms of Service');return false;};
    //if($('submit_btn')){$('submit_btn').disabled=true;$('submit_btn').value='Uploading...';}
    generateSID(f1);

    setTimeout("openStatusWindow()",500);
    window.scrollTo(0,0);
    form_action = form_action.split('?')[0]+'?upload_id='+UID+'&js_on=1'; //cleaning old query to avoid ReUpload bugs
    setFormAction(f1,form_action);
    f1.action=form_action;
}

function checkExt(obj)
{
    value = obj.value;
    if(value=="")return true;
    var re1 = new RegExp("^.+\.("+ext_allowed+")$","i");
    var re2 = new RegExp("^.+\.("+ext_not_allowed+")$","i");
    if( (ext_allowed && !re1.test(value)) || (ext_not_allowed && re2.test(value)) )
    {
        str='';
        if(ext_allowed)str+="\nOnly these extensions are allowed: "+ext_allowed.replace(/\|/g,',');
	if(ext_not_allowed)str+="\nThese extensions are not allowed:"+ext_not_allowed.replace(/\|/g,',');
        alert("Extension not allowed for file: \"" + value + '"'+str);
        return false;
    }

    return true;
}

function addUploadSlot()
{
  cx++;
  slots++;
  if(slots==max_upload_files){$('x_add_slot').style.visibility='hidden';}

  var new_slot = document.createElement( 'input' );
  new_slot.type = 'file';
  new_slot.name = 'file_'+cx;
  $('slots').appendChild(new_slot);
  $('slots').appendChild( document.createElement('br') );
}

function fixLength(str)
{
 if(str.length<show_fname_chars)return str;
 return '...'+str.substring(str.length-show_fname_chars-1,str.length);
}

function MultiSelector( list_target, max_files, max_size, descr_mode )
{
	this.list_target = $(list_target);
	this.count = 0;
	this.id = 0;
	if( max_files ){
		this.max = max_files;
	} else {
		this.max = -1;
	};
	$('x_max_files').innerHTML = max_files;
    $('x_max_size').innerHTML = max_size+" Mb";
	this.addElement = function( element )
    {
		if( element.tagName == 'INPUT' && element.type == 'file' )
        {
           element.name = 'file_' + this.id++;
           element.multi_selector = this;
           element.onchange = function()
           {
               if(!checkExt(element))return;
               //if(max_files<=1)return;
               if (navigator.appVersion.indexOf("Mac")>0 && navigator.appVersion.indexOf("MSIE")>0)return;
               var new_element = document.createElement( 'input' );
               new_element.type = 'file';
               new_element.size = element.size;

               //this.parentNode.insertBefore( new_element, this );
               this.parentNode.appendChild( new_element, this );
               this.multi_selector.addElement( new_element );
               this.multi_selector.addListRow( this );

               // Hide this: we can't use display:none because Safari doesn't like it
               this.style.position = 'absolute';
               this.style.left = '-9000px';
           };
           // If we've reached maximum number, disable input element
           if( this.max != -1 && this.count >= this.max ){element.disabled = true;};

           this.count++;
           this.current_element = element;
		} 
        else {alert( 'Error: not a file input element' );};
	};

	this.addListRow = function( element )
    {
		var new_row = document.createElement( 'div' );

		var new_row_button = document.createElement( 'input' );
		new_row_button.type = 'button';
		new_row_button.value = 'Delete';

		new_row.element = element;

		new_row_button.onclick= function()
        {
			this.parentNode.element.parentNode.removeChild( this.parentNode.element );
			this.parentNode.parentNode.removeChild( this.parentNode );
			this.parentNode.element.multi_selector.count--;
			this.parentNode.element.multi_selector.current_element.disabled = false;
			return false;
		};

		new_row.appendChild( new_row_button );

		currenttext=document.createTextNode(" "+fixLength(element.value));
                var span1 = document.createElement( 'span' );
                span1.className = 'xfname';
                span1.appendChild( currenttext );

        new_row.appendChild( span1 );

        if(descr_mode)
        {
            var new_row_descr = document.createElement( 'input' );
    		new_row_descr.type = 'text';
    		new_row_descr.value = '';
            new_row_descr.name = element.name+'_descr';
            new_row_descr.className='fdescr';
            new_row_descr.setAttribute('id',element.name+'_descr');
            new_row_descr.setAttribute('maxlength', 32);
            new_row.appendChild( document.createElement('br') );
            var span2 = document.createElement( 'span' );
                span2.className = 'xdescr';
                span2.appendChild( document.createTextNode('Description:') );
            new_row.appendChild( span2 );
            new_row.appendChild( new_row_descr );
        }
        

		this.list_target.appendChild( new_row );
	};
};

function getFormAction(f)
{
    if(!f)return;
    for(i=0;i<=f.attributes.length;i++)
    {
        if(f.attributes[i] && f.attributes[i].name.toLowerCase()=='action')return f.attributes[i].value;
    }
    return '';
}

function setFormAction(f,val)
{
    for(i=0;i<=f.attributes.length;i++)
    {
        if(f.attributes[i] && f.attributes[i].name.toLowerCase()=='action')f.attributes[i].value=val;
    }
}

function InitUploadSelector()
{
    if($('files_list'))
    {
        var multi_selector = new MultiSelector( 'files_list', max_upload_files, max_upload_size, descr_mode );
        multi_selector.addElement( $( 'my_file_element' ) );
    }
}

function findPos(obj) {
	var curleft = curtop = 0;
	if (obj.offsetParent) {
		curleft = obj.offsetLeft
		curtop = obj.offsetTop
		while (obj = obj.offsetParent) {
			curleft += obj.offsetLeft
			curtop += obj.offsetTop
		}
	}
	return [curleft,curtop];
}

function countDown()
{
    num = parseInt( $('countdown').innerHTML )-1;
    if(num<=0)
    {
        $('btn_download').disabled=false;
        $('countdown_str').style.display='none';
    }
    else
    {
        $('countdown').innerHTML = num;
        setTimeout("countDown()",1000);
    }
}
