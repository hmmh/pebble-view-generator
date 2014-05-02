/* lexical grammar */
%{
    var mustache = require('mustache');
    var fs = require('fs');

    // used to store the name of the topmost layer, 
    // the one enclosing all other objects
    var root_layer_name = false;

    // will contain all the template generated allocation and initialization code. 
	var code_stack = [];
    // used to maintain a list of all identifiers with their type as a key.
    // Two text layers identified by 'identifier1' and 'identifier2' and one inverter layer identified 
    // as 'my_inverter_layer' would look somewhat like this:
    //     { text : [ 'identifier1', 'identifier2'], 
    //       inverter : [ 'my_inverter_layer'], 
    //       _global_ : { identifier1 : true, identifier2 : true, my_inverter_layer : true } 
    //     }
	var identifiers = {};
    // used to keep a list of all the identifiers used in the source file. Mainly for syntax sanity checks.
    identifiers['_global_'] = {};

    // will contain all the template generated code for freeing the objects
	var destructor_stack = [];

	var context_stack = [];
	var context = {};
    // not currently in use - will later support a 'auto' option for layer dimensions based on their child elements.
    var max_dimensions = {};

	function render( template, method, context ) {
		return mustache.render( fs.readFileSync( __dirname + '/../template/' + template + '.' + method + '.mustache', 'utf8'), context );
	}

	function to_camel_case( string ) {
	  return string.replace(/^.|_./g, function( char, index) {
	    return index == 0 ? char.toUpperCase() : char.substr(1).toUpperCase();
	  });
	}

	function context_push() {
		context_stack.push( context );
		context = {};
	}
%}

/* Definitions */
%lex
%%

/* Rules */

\s+	 	                                            						  { /* skip whitespace */ }
"#".*\n?																	  { /* skip comments */ }

"view"		                                    						      { context_push(); return 'VIEW'; }
"subview"                                                                     { context_push(); return 'SUBVIEW'; }
"layer"		                                								  { context_push(); return 'LAYER'; }
"bitmap"	                                								  { context_push(); return 'BITMAP'; } 
"text"		                                								  { context_push(); return 'TEXT'; }
"font"																		  { context_push(); return 'FONT'; }
"inverter"	                                								  { context_push(); return 'INVERTER'; }

"as"																		  { return 'AS'; }
"'"([a-zA-Z_]+[a-zA-Z0-9_]*?)"'"      	                       		          { return 'IDENTIFIER'; }
\$([a-zA-Z_]+[a-zA-Z0-9]*(("->"|\.)[a-zA-Z_]+[a-zA-Z0-9]*)?) 				  { return 'VARIABLE'; }
"\""("\\\""|[^"])*?"\""                          							  { return 'STRING'; }
([A-Z]+[_A-Z0-9]*)		        											  { return 'RESOURCE'; }
"["                                             							  { return 'BRACE_OPEN'; }
"]"                                             							  { return 'BRACE_CLOSE'; }
"("\s*?"width:"(\d+)\s+"height:"(\d+)\s+"top:"(\-?\d+)\s+"left:"(\-?\d+)\s*?")"     { return 'POSITION_AND_DIMENSION'; }
"black"                                               						  { return 'COLOR_BLACK'; }
"white"                                                          			  { return 'COLOR_WHITE'; }
"clear"																		  { return 'COLOR_CLEAR'; }
"hidden"                                        							  { return 'HIDDEN'; }
"on"                                                                          { return 'ON'; }
"with parameters ("[^)]*")"													  { return 'PARAMETERS'; }
"using font"                                                                  { return 'FONT_SELECTION' }
";"																			  { return 'SEMICOLON'; }
<<EOF>>                                           							  { return 'EOF'; }
/lex

%Start view_definition

%%

/**
 * parses a view definition.
 *
 * this section parses the view definition top-level element. 
 * 
 * The view definition will determine the name of the view access functions and of the 
 * header and implementation files. There may only ever be one view entry per file.
 *
 * Example:
 *
 *     view as 'name_of_the_view' [ ... ]
 *
 * a view definition may only contain a single layer definition.
 */
view_definition
        : VIEW id optional_parameter BRACE_OPEN layer BRACE_CLOSE EOF
        {
        	context.name_in_camel_case = to_camel_case( context.name );
        	context.creators = code_stack;
        	context.destructors = destructor_stack;
        	context.identifiers = identifiers;
            context.root_layer_name = root_layer_name;

        	var header = render( $$, 'generate.header', context );
        	var implementation = render( $$, 'generate.implementation', context );

            var filename_header = context.name + '_view.h';
            var filename_implementation = context.name + '_view.c';

            console.log( 'creating header file \'' + filename_header + '\'' );
        	fs.writeFileSync( filename_header, header, 'utf8' );

            console.log( 'creating implementation file \'' + filename_implementation + '\'' );
        	fs.writeFileSync( filename_implementation, implementation, 'utf8' );

        	context = context_stack.pop();
        }
		;

/**
 * parses a layer definition.
 *
 * A layer directly corresponds to the pebble layer object.
 * It can either stand on it's own or serve as a container for other elements.
 *
 * parameters:
 * - the variable name of the layer 
 * - the dimension and position in it's parent layer or window
 * - an optional 'hidden' parameter. If specified, the layer will be flagged as hidden.
 *
 * Example:
 *
 *     layer as 'the_name_of_the_layer' (width:144 height:125 top:0 left:0) [ ... ]
 * or
 *     layer as 'the_name_of_the_layer' (width:144 height:125 top:0 left:0);
 *
 * A view definition may only contain a single layer definition.
 */
layer
        : LAYER id position_and_dimension visibility BRACE_OPEN ui_components BRACE_CLOSE
        {
        	if ( ! root_layer_name ) {
        		context.is_root_layer = true;
        		root_layer_name = context.name;
        	}
        	context.creators = code_stack;
        	code_stack = [];
        	code_stack.push( render( $$, 'create', context ) );
        	if( ! identifiers[ $$ ] ) {
        		identifiers[ $$ ] = [];
        	}
       		identifiers[ $$ ].push( context.name );
        	destructor_stack.push( render( $$, 'destroy', context ) );
        	context = context_stack.pop();
        }
        | LAYER id position_and_dimension visibility
        { 
        	code_stack.push( render( $$, 'create', context ) );
        	if( ! identifiers[ $$ ] ) {
        		identifiers[ $$ ] = [];
        	}
       		identifiers[ $$ ].push( context.name );
        	destructor_stack.push( render( $$, 'destroy', context ) );
        	context = context_stack.pop();
        }
        ;

/**
 * parses a subview definition.
 *
 * subviews provide a way to break down complex views. 
 *
 * parameters:
 * - the name of the SubView to be referenced 
 * - a (optional) parameter list to be passed to the subviews create function
 * - the variable name of the SubView layer 
 * - an optional 'hidden' parameter. If specified, the subview will be flagged as hidden.
 *
 * Example:
 *
 *     subview 'DemoView' as 'demo_view';
 */
subview
        : SUBVIEW identifier optional_parameter id visibility
        {
            context.view_name = $2;
            context.view_name_in_camel_case = to_camel_case( context.view_name );
            code_stack.push( render( $$, 'create', context ) );
            if( ! identifiers[ $$ ] ) {
                identifiers[ $$ ] = [];
            }
            identifiers[ $$ ].push( { "type": context.view_name_in_camel_case, "name": context.name } );
            destructor_stack.unshift( render( $$, 'destroy', context ) );
            context = context_stack.pop();            
        }
        ;

/**
 * parses a inverter definition.
 *
 * directly corresponds to the pebble inverter layer.
 *
 * parameters:
 * - the variable name of the inverter layer 
 * - the dimension and position of the inverter layer in it's parent layer
 * - an optional 'hidden' parameter. If specified, the layer will be flagged as hidden.
 * 
 * Example:
 *
 *     inverter as 'name_of_the_inverter' (width:144 height:125 top:0 left:0);
 */
inverter
        : INVERTER id position_and_dimension visibility
        {
        	code_stack.push( render( $$, 'create', context ) );
        	if( ! identifiers[ $$ ] ) {
        		identifiers[ $$ ] = [];
        	}
       		identifiers[ $$ ].push( context.name );
        	destructor_stack.unshift( render( $$, 'destroy', context ) );
        	context = context_stack.pop();
        } 
        ;

/**
 * parses a bitmap definition.
 *
 * parameters:
 * - a pebble bitmap resource id 
 * - the variable name of the bitmap layer 
 * - the dimension and position of the bitmap in it's parent layer
 * - an optional 'hidden' parameter. If specified, the bitmap will be flagged as hidden.
 *
 * Example:
 *
 *     bitmap RESOURCE_ID_MY_IMAGE as 'name_of_my_image' (width:144 height:125 top:0 left:0);
 */
bitmap
        : BITMAP RESOURCE id position_and_dimension visibility
        {
        	context.resource_id = $2;
        	code_stack.push( render( $$, 'create', context ) );
        	if( ! identifiers[ $$ ] ) {
        		identifiers[ $$ ] = [];
        	}
       		identifiers[ $$ ].push( context.name );
        	destructor_stack.unshift( render( $$, 'destroy', context ) );
        	context = context_stack.pop();
        }
        ;

/**
 * parses a text definition.
 *
 * creates a pebble text layer.
 * 
 * parameters:
 * - the output text, either given as a constant string (in quotes) or as a variable name with a leading dollar character
 * - the variable name of the text layer 
 * - the dimensions of the text layer and it's position in the enclosing layer in pixels
 * - the font to use. the font has to be defined in the source file before the text element.
 * - the fore- and background color of the text. the background - if not specified - will default to the 'clear' color.
 * - an optional 'hidden' parameter. If specified, the text will be created hidden.
 *
 * Example:
 *
 *     text "my text" as 'name_of_my_text' (width:60 height:17 top:3 left:22) using font 'name_of_my_font' black on white;
 */
text
        : TEXT string_or_var id position_and_dimension font_selection color_with_optional_background visibility
        {
        	code_stack.push( render( $$, 'create', context ) );
        	if( ! identifiers[ $$ ] ) {
        		identifiers[ $$ ] = [];
        	}
       		identifiers[ $$ ].push( context.name );
        	destructor_stack.unshift( render( $$, 'destroy', context ) );
        	context = context_stack.pop();
        }
        ;

/**
 * parses a font definition.
 *
 * will load a custom font in case the resource id doesn't begin with FONT_ 
 * 
 * parameters:
 * - a pebble resource id  
 * - the variable name of the font layer 
 *
 * Example:
 *
 *     font RESOURCE_ID_FONT_CODERS_CRUX_17 as 'font_coders_crux';
 * or
 *     font FONT_KEY_GOTHIC_24_BOLD as 'font_gothic_24';
 *
 */
font
		: FONT RESOURCE id
		{
			var regex = /^FONT/;
			context.internal_font = regex.test( $2 );
			context.resource_id = $2;			
        	code_stack.push( render( $$, 'create', context ) );
        	if( ! identifiers[ $$ ] ) {
        		identifiers[ $$ ] = [];
        	}
       		identifiers[ $$ ].push( context.name );
        	destructor_stack.unshift( render( $$, 'destroy', context ) );
        	context = context_stack.pop();
		}     
		;

font_selection
        : FONT_SELECTION identifier
        {
            context.font = $2;
            if ( identifiers[ '_global_' ][ $2 ] == undefined ) {
                console.log( 'error: text object is referencing unknown font identifier \'' + $2 + '\' in line ' + @2.first_line );
            }
        }
        ;

ui_component
		: layer SEMICOLON
        | inverter SEMICOLON
        | text SEMICOLON
        | bitmap SEMICOLON
        | font SEMICOLON
        | subview SEMICOLON
        ;

ui_components
        : ui_component 
        | ui_components ui_component
        ;

id
        : AS identifier
        {
            context.name = $2;
        	if ( identifiers[ '_global_' ][ context.name ] ) {
        		console.log( 'error: duplicate identifier \'' + context.name + '\' in line ' + @2.first_line );
        	} 
            identifiers[ '_global_' ][ context.name ] = true;
        }
        ;

identifier
        : IDENTIFIER
        {
            $$ = $1.substring( 1, $1.length - 1 ); 
        }
        ;

optional_parameter
		:
		| PARAMETERS
		{ 
			var regex = /\(\s*(.*?)\s*\)$/
			context.parameters = $1.match( regex )[1];
		}
		;

position_and_dimension
		: POSITION_AND_DIMENSION
		{
			var regex = /\(\s*?width:(\d+)\s+height:(\d+)\s+top:(-?\d+)\s+left:(-?\d+)\s*?\)/;
			var match = $1.match( regex );
			context.width = match[1];
			context.height = match[2];
			context.top = match[3];
			context.left = match[4];

            // preparation for later introduction of 'auto' support
            max_dimensions.width = Math.max( max_dimensions.width, context.left + context.width );
            max_dimensions.height = Math.max( max_dimensions.height, context.top + context.height );
		}
		;

string_or_var
        : VARIABLE
        { context.variable = $1.substring( 1 ); }
        | STRING
        { context.string = $1.substring( 1, $1.length - 1 ); }
        ;

color_with_optional_background
        : color
        { context.foreground = $1; }
        | color ON color
        {
        	context.foreground = $1;
        	context.background = $3;
        }
        ;

color
        : 
        | COLOR_BLACK
        { $$ = 'GColorBlack'; }
        | COLOR_WHITE
        { $$ = 'GColorWhite'; }
        | COLOR_CLEAR
        { $$ = 'GColorClear'; }
        ;

visibility
        :
        | HIDDEN
        { context.hidden = true; }
        ;

%% 
