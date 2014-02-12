/*
 * File:        ColResize.js
 * Version:     0.5.1
 * CVS:         $Id$
 * Description: Column resizing in DataTables
 * Author:      Koos van der Kolk, based on work of Allan Jardine (www.sprymedia.co.uk)
 * Created:     Fri 10 Feb 2012
 * Language:    Javascript
 * License:     GPL v2 or BSD 3 point style
 * Project:     DataTables
 * Contact:     koosvdkolk@gmail.com
 *
 * This source file is free software, under either the GPL v2 license or a
 * BSD style license, available at:
 *   http://datatables.net/license_gpl2
 *   http://datatables.net/license_bsd
 *
 */
(function($, window, document) {
  /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
   * DataTables plug-in API functions
   *
   * This are required by ColResize in order to perform the tasks required, and also keep this
   * code portable, to be used for other column reordering projects with DataTables, if needed.
   * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */


  /**
   * Plug-in for DataTables which will reorder the internal column structure by taking the column
   * from one position (iFrom) and insert it into a given point (iTo).
   *  @method  $.fn.dataTableExt.oApi.fnColResize
   *  @param   object oSettings DataTables settings object - automatically added by DataTables!
   *  @param   int iFrom Take the column to be repositioned from this point
   *  @param   int iTo and insert it into this point
   *  @returns void
   */
  $.fn.dataTableExt.oApi.fnColResize = function ( oSettings, iFrom, iTo )
  {
    var i, iLen, j, jLen, iCols=oSettings.aoColumns.length, nTrs, oCol;

    /* Sanity check in the input */
    if ( iFrom == iTo )
    {
      /* Pointless reorder */
      return;
    }

    if ( iFrom < 0 || iFrom >= iCols )
    {
      this.oApi._fnLog( oSettings, 1, "ColResize 'from' index is out of bounds: "+iFrom );
      return;
    }

    if ( iTo < 0 || iTo >= iCols )
    {
      this.oApi._fnLog( oSettings, 1, "ColResize 'to' index is out of bounds: "+iTo );
      return;
    }
  };




  /**
   * ColResize provides column visiblity control for DataTables
   * @class ColResize
   * @constructor
   * @param {object} DataTables object
   * @param {object} ColResize options
   */
  ColResize = function( oTable, oOpts )
  {
    this.oTable = oTable;

    /* Santiy check that we are a new instance */
    if ( !this.CLASS || this.CLASS != "ColResize" )
    {
      alert( "Warning: ColResize must be initialised with the keyword 'new'" );
    }

    if ( typeof oOpts == 'undefined' )
    {
      oOpts = {};
    }


    /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
     * Public class variables
     * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

    /**
     * @namespace Settings object which contains customisable information for ColResize instance
     */
    this.s = {
      /**
       * DataTables settings object
       *  @property dt
       *  @type     Object
       *  @default  null
       */
      "dt": null,

      /**
       * Initialisation object used for this instance
       *  @property init
       *  @type     object
       *  @default  {}
       */
      "init": oOpts,

      /**
       * Number of columns to fix (not allow to be reordered)
       *  @property fixed
       *  @type     int
       *  @default  0
       */
      "fixed": 0,

      /**
       * @namespace Information used for the mouse drag
       */
      "mouse": {
        "startX": -1,
        "startY": -1,
        "offsetX": -1,
        "offsetY": -1,
        "target": -1,
        "targetIndex": -1,
        "fromIndex": -1
      },

      /**
       * Information which is used for positioning the insert cusor and knowing where to do the
       * insert. Array of objects with the properties:
       *   x: x-axis position
       *   to: insert point
       *  @property aoTargets
       *  @type     array
       *  @default  []
       */
      "aoTargets": []
    };


    /**
     * @namespace Common and useful DOM elements for the class instance
     */
    this.dom = {
      /**
       * Dragging element (the one the mouse is moving)
       *  @property drag
       *  @type     element
       *  @default  null
       */
      "drag": null,

      /**
       * Resizing a column
       *  @property drag
       *  @type     element
       *  @default  null
       */
      "resize": null,

      /**
       * The insert cursor
       *  @property pointer
       *  @type     element
       *  @default  null
       */
      "pointer": null
    };


    /* Constructor logic */
    this.s.dt = oTable.fnSettings();
    this._fnConstruct();

    /* Store the instance for later use */
    ColResize.aoInstances.push( this );
    return this;
  };



  ColResize.prototype = {
    /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
     * Public methods
     * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

    "fnReset": function ()
    {
      var a = [];
      for ( var i=0, iLen=this.s.dt.aoColumns.length ; i<iLen ; i++ )
      {
        a.push( this.s.dt.aoColumns[i]._ColResize_iOrigCol );
      }

      this._fnOrderColumns( a );
    },


    /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
     * Private methods (they are of course public in JS, but recommended as private)
     * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

    /**
     * Constructor logic
     *  @method  _fnConstruct
     *  @returns void
     *  @private
     */
    "_fnConstruct": function ()
    {

      var that = this;
      var i, iLen;

      /* Columns discounted from reordering - counting left to right */
      if ( typeof this.s.init.iFixedColumns != 'undefined' )
      {
        this.s.fixed = this.s.init.iFixedColumns;
      }

      /* Add event handlers for the resize, and also mark the original column order */
      for ( i=0, iLen=this.s.dt.aoColumns.length ; i<iLen ; i++ )
      {
        if ( i > this.s.fixed-1 )
        {
          this._fnMouseListener( i, this.s.dt.aoColumns[i].nTh );
        }
      }

      /* State saving */
      this.s.dt.aoStateSave.push( {
        "fn": function (oS, sVal) {
          return that._fnStateSave.call( that, sVal );
        },
        "sName": "ColResize_State"
      } );
    },

    /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
     * Mouse drop and drag
     */

    /**
     * Add a mouse down listener to a particluar TH element
     *  @method  _fnMouseListener
     *  @param   int i Column index
     *  @param   element nTh TH element clicked on
     *  @returns void
     *  @private
     */
    "_fnMouseListener": function ( i, nTh )
    {
      var that = this;
      $(nTh).bind( 'mousemove.ColResize', function (e) {
        $(nTh).unbind('mousedown.ColResize');

        if (that.dom.resize === null)
        {
          /* Store information about the mouse position */
          var nThTarget = e.target.nodeName == "TH" ? e.target : $(e.target).parents('TH')[0];
          var offset = $(nThTarget).offset();
          var nInnerWidth = $(nThTarget).innerWidth();
          var nOuterWidth = $(nThTarget).outerWidth();

          /* are we on the col border (if so, resize col) */
          if (e.pageX >= Math.round(offset.left + nInnerWidth) && e.pageX <= Math.round(offset.left + nOuterWidth))
          {
            that._fnSetElementCursor(nThTarget, true);
            $(nTh).bind( 'mousedown.ColResize', function (e) {
              /* call handler */
              that._fnMouseDown.call( that, e, nTh );

              return false;
            } );
          }else{
            that._fnSetElementCursor(nThTarget, false);
          }
        }
        else
        {
          that._fnSetElementCursor(nThTarget, false);
        }
      } );
    },
    /**
     * Assigns the css cursor property to an element
     * @param boolean bForceResizeMode If set to true, the element gets the cursor:col-resize value, if false: pointer
     **/
    "_fnSetElementCursor": function(element, bForceResizeMode){
      if (!element) return;
      var cursorStyle = (bForceResizeMode === undefined || bForceResizeMode === false) ? "pointer" : "col-resize";

      $(element).css({
        'cursor': cursorStyle
      });
    },

    /**
     * Mouse down on a TH element in the table header
     *  @method  _fnMouseDown
     *  @param   event e Mouse event
     *  @param   element nTh TH element to be dragged
     *  @returns void
     *  @private
     */
    "_fnMouseDown": function ( e, nTh )
    {
      var
      that = this,
      oTable = this.oTable,
      aoColumns = this.s.dt.aoColumns;
      nTh = $(nTh);

      /* temporarily disable sorting, because click event trigger sorting */
      oTable.fnSortOnOff( '_all', false );

      /* store width of last column */
      that.nLastTh = $(nTh).parent().children('th:last');
      that.nLastThOriginalWidth = that.nLastTh.width();

      /* store some variables */
      this.s.mouse.startX = e.pageX;
      this.s.mouse.startWidth = nTh.width();
      this.s.mouse.resizeElem = nTh;
      var nThNext = nTh.next();
      this.s.mouse.nextStartWidth = nThNext.width();
      that.dom.resize = true;


      $(document).unbind( 'mousemove.ColResize');
      $(document).unbind( 'mouseup.ColResize');

      /* Add event handlers to the document */
      $(document).bind( 'mousemove.ColResize', function (e) {
        that._fnMouseMove.call( that, e );
      } );

      $(document).bind( 'mouseup.ColResize', function (e) {
        /* enable sorting on click, which will be fired after mouseup */
        $(document).one( 'click.ColResize', function (e) {
          oTable.fnSortOnOff( '_all', true );
        } );

        /* set the column width in the table */
        that._fnSetColumnWidth(nTh);
        if (nTh.index()!== that.nLastTh.index()) {
          that._fnSetColumnWidth(that.nLastTh);
        }

        /* prevent bubbling etc */
        that._fnMouseUp.call( that, e );
        e.preventDefault();
        e.cancelBubble = true;
        e.stopImmediatePropagation();

        /* set cursor css */
        that._fnSetElementCursor(nTh, false);

        /* unbind handlers */
        $(document).unbind( 'mousemove.ColResize');
        $(document).unbind( 'mouseup.ColResize');
        return false;


      } );


    },
    "_fnSetColumnWidth" : function(nTh){
      var oTable = this.oTable;
      var aoColumns = this.s.dt.aoColumns;
      var iColumnIndex = $(nTh).index();

      /* set it in datatable settings and redraw table */
      aoColumns[iColumnIndex].sWidth = nTh.width() +  'px';

      $(oTable).dataTable().fnDraw();
    },


    /**
     * Deal with a mouse move event while dragging a node
     *  @method  _fnMouseMove
     *  @param   event e Mouse event
     *  @returns void
     *  @private
     */
    "_fnMouseMove": function ( e )
    {
      var that = this;

      /* are we resizing a column ? */
      if (this.dom.resize) {
        var nTh = this.s.mouse.resizeElem;
        var nThNext = $(nTh).next();
        var moveLength = e.pageX-this.s.mouse.startX;
        if (moveLength != 0)

        /* resize the column header */
        $(nTh).width(this.s.mouse.startWidth + moveLength);

        /* also resize the last column header if the column width is decreased */
        if (moveLength<0 && that.nLastTh.index() !== jQuery(nTh).index() ) {
          that.nLastTh.width(that.nLastThOriginalWidth+Math.abs(moveLength));
        }
      }
    },


    /**
     * Finish off the mouse drag and insert the column where needed
     *  @method  _fnMouseUp
     *  @param   event e Mouse event
     *  @returns void
     *  @private
     */
    "_fnMouseUp": function ( e )
    {
      var that = this;

      this.dom.resize = null;
      return false;
    }
  };





  /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
   * Static parameters
   * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

  /**
   * Array of all ColResize instances for later reference
   *  @property ColResize.aoInstances
   *  @type     array
   *  @default  []
   *  @static
   */
  ColResize.aoInstances = [];

  /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
   * Constants
   * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

  /**
   * Name of this class
   *  @constant CLASS
   *  @type     String
   *  @default  ColResize
   */
  ColResize.prototype.CLASS = "ColResize";


  /**
   * ColResize version
   *  @constant  VERSION
   *  @type      String
   *  @default   As code
   */
  ColResize.VERSION = "0.5.1";
  ColResize.prototype.VERSION = ColResize.VERSION;





  /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
   * Initialisation
   * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

  /*
   * Register a new feature with DataTables
   */
  if ( typeof $.fn.dataTable == "function" &&
    typeof $.fn.dataTableExt.fnVersionCheck == "function" &&
    $.fn.dataTableExt.fnVersionCheck('1.8.0') )
  {

    /*
     * Turn On/Off Sorting capability
     *
     * @param {object} oSettings DataTables settings object
     * @param {array} | {string} aiColumns Array of columns or string == '_all'
     * @param {boolean} bOn True to enable, false to disable
     */
    $.fn.dataTableExt.oApi.fnSortOnOff  = function ( oSettings, aiColumns, bOn )
    {
      var cols = typeof aiColumns == 'string' && aiColumns == '_all' ? oSettings.aoColumns : aiColumns;

      for ( var i = 0, len = cols.length; i < len; i++ ) {
        oSettings.aoColumns[ i ].bSortable = bOn;
      }
    }

    $.fn.dataTableExt.aoFeatures.push( {
      "fnInit": function( oDTSettings ) {
        var oTable = oDTSettings.oInstance;

        if ( typeof oTable._oPluginColResize == 'undefined' ) {
          var opts = typeof oDTSettings.oInit.oColResize != 'undefined' ?
            oDTSettings.oInit.oColResize : {};
          oTable._oPluginColResize = new ColResize( oDTSettings.oInstance, opts );
        } else {
          oTable.oApi._fnLog( oDTSettings, 1, "ColResize attempted to initialise twice. Ignoring second" );
        }

        return null; /* No node to insert */
      },
      "cFeature": "z",
      "sFeature": "ColResize"
    } );
  }
  else
  {
    alert( "Warning: ColResize requires DataTables 1.8.0 or greater - www.datatables.net/download");
  }

})(jQuery, window, document);
