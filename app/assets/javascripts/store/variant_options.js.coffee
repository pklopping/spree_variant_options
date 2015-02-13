$.extend
  keys: (obj) ->
    a = []
    $.each obj, (k) =>
      a.push k
    return a


Array.find_matches = (a) ->
  m = []
  a = a.sort()
  i = a.length
  while(i--)
    if (a[i - 1] == a[i])
      m.push(a[i])
  if (m.length == 0) 
    return false
  return m

class window.VariantOptions

  constructor: (params) ->

    @options = params['options'];
    @allow_backorders = !params['track_inventory_levels'] ||  params['allow_backorders']
    @allow_select_outofstock = params['allow_select_outofstock']
    @default_instock = params['default_instock']
    @wrapper = params['wrapper']
    @isCart = params['isCart']

    @variant
    @divs
    @parent
    @index = 0
    @selection = []
    @buttons

    @colorButtons = (@isCart) ? 'select.Color' : '.colors'

    @init()

  init: ->
    @divs = $(@wrapper).find('.variant-options');
    #Enable Colors
    @update();
    @enable_size(@parent.find('select.Size'))
    #Enable Sizes
    @enable_color(@parent.find(@colorButtons))
    #Enable Colors
    @enable_size(@parent.find('select.Size'))
    #Enable Sizes
    @enable_color(@parent.find(@colorButtons))

    if @isCart
      $(@wrapper).find('select.Size').trigger('change')
      $(@wrapper).find('select.Color').trigger('change')

    @toggle()

    if @default_instock
      @divs.each ->
        $(this).find(".variant-option-values .in-stock:first").click()

  get_index: (parent) ->
    parseInt($(parent).attr('class').replace(/[^\d]/g, ''))

  update: (i) ->
    @index = if isNaN(i) then @index else i
    @parent = $(@divs.get(@index))
    @buttons = @parent.find('.option-value')

  disable: (btns) ->
    return btns.removeClass('selected')

  enable_size: (btns) ->
    bt = btns.not('.unavailable').removeClass('locked').unbind('click')
    if (!@allow_select_outofstock && !@allow_backorders)
      bt = bt.filter('.in-stock')
    bt.off('change').on('change', (event) =>
      @handle_size_change(event)
    ).filter('.auto-click').removeClass('auto-click').click()

  enable_color: (btns) ->
    bt = btns.not('.unavailable').removeClass('locked').unbind('click')
    if (!@allow_select_outofstock && !@allow_backorders)
      bt = bt.filter('.in-stock')
    if @isCart
      bt.parent().off('change').on('change', (event) =>
        @handle_color_change(event)
      ).filter('.auto-click').removeClass('auto-click').click()
    else
      bt.off('click').on('click', (event) =>
        @handle_color_change(event)
      ).filter('.auto-click').removeClass('auto-click').click()

  advance: () ->
    @index = @index + 1
    @update()
    @inventory(@buttons.removeClass('locked'))
    @enable_size(@buttons)
    @enable_color(@buttons)

  inventory: (btns) ->
    keys = undefined
    variants = undefined
    count = 0
    selected = {}
    sels = []
    # Grab selected Size
    tmp = $(@wrapper).find('select.Size').val()
    opt = $(@wrapper).find('select.Size').find('option[value="'+tmp+'"]')
    # var opt = $(@wrapper).find('select.Size').find(':selected');
    sels.push(opt.data('rel'));
    # Grab selected color

    $.each sels, (key, value) =>
      key = value.split('-')
      v = @options[key[0]][key[1]]
      keys = $.keys(v)
      m = Array.find_matches(@selection.concat(keys))
      if @selection.length == 0
        @selection = keys
      else if (m)
        @selection = m

    btns.removeAttr('disabled').removeClass('in-stock out-of-stock unavailable').each (i, element) =>
      variants = @get_variant_objects($(element).data('rel'))
      keys = $.keys(variants)
      if keys.length == 0
        @disable $(element).addClass('unavailable locked').unbind('click')
        if $(element).is('option')
          @disable $(element).attr('disabled','true')
          $(element).parent().trigger("modified")
      else if (keys.length == 1)
        _var = variants[keys[0]]
        if (@allow_backorders || _var.count)
          if @selection.length == 1
            class_to_add = 'in-stock auto-click' 
          else
            class_to_add = 'in-stock'
        else
          class_to_add = 'out-of-stock'
        in_stock = $(element).addClass(class_to_add)
        if ($(element).hasClass('out-of-stock') && $(element).is('option'))
          $(element).attr('disabled','true')
          $(element).parent().trigger("modified")
      else if (@allow_backorders)
        $(element).addClass('in-stock');
      else
        $.each variants, (key, value) =>
          count = count + value.count
        if (count > 0) 
          $(element).addClass('in-stock')
        else
          $(element).addClass('out-of-stock')
          if $(element).is('option')
            $(element).attr('disabled','true')
            $(element).parent().trigger("modified")

  get_variant_objects: (rels) ->
    # var i, ids, obj, 
    variants = {}
    if (typeof(rels) == 'string') 
      rels = [rels]
    # var otid, ovid, opt, opv;
    i = rels.length;
    try
      while (i--)
        ids = rels[i].split('-')
        otid = ids[0]
        ovid = ids[1]
        opt = @options[otid]
        if (opt)
          opv = opt[ovid]
          ids = $.keys(opv)
          if (opv && ids.length)
            j = ids.length
            while (j--)
              obj = opv[ids[j]]
              if (obj && $.keys(obj).length && 0 <= @selection.indexOf(obj.id.toString()))
                variants[obj.id] = obj
    catch error
      # console.log(error);
    variants

  to_f: (string) ->
    parseFloat(string.replace(/[^\d\.]/g, ''))

  find_variant: (selected_option) ->
    selected = @divs.find('.selected').not('li, select')
    variants = @get_variant_objects( if (@isCart) then selected.data('rel') else selected_option.data('rel'))
    if (selected.length == @divs.length)
      if (@count_variants(variants) == 1)
        return @variant = variants[@first_variant_key(variants)]
      else
        return @variant = variants[@selection[0]]
    else
      prices = []
      $.each variants, (key, value) =>
        prices.push(value.price)
      prices = $.unique(prices).sort (a, b) =>
        return if (@to_f(a) < @to_f(b)) then -1 else 1
      if (prices.length == 1)
        $(@wrapper).find('.price').html('<span class="price assumed">' + prices[0] + '</span>')
      else
        $(@wrapper).find('.price').html('<span class="price from">' + prices[0] + '</span> - <span class="price to">' + prices[prices.length - 1] + '</span>')
      false

  count_variants: (variants) ->
    count = 0
    for key in variants
      count = count + 1
    count

  first_variant_key: (variants) ->
    for key in variants
      return key

  toggle: () ->
    if (@variant)
      $(@wrapper).find('#variant_id, form[data-form-type="variant"] input[name$="[variant_id]"]').val(@variant.id)
      $(@wrapper).find('#product-price .price').removeClass('unselected').text(@variant.price);
      if (@variant.count > 0 || @allow_backorders)
        $(@wrapper).find('#cart-form button[type=submit]').attr('disabled', false).fadeTo(100, 1);
      $(@wrapper).find('form[data-form-type="variant"] button[type=submit]').attr('disabled', false).fadeTo(100, 1);
      try
        @show_variant_images(@variant.id)
      catch error
        # depends on modified version of product.js
    else
      $(@wrapper).find('#variant_id, form[data-form-type="variant"] input[name$="[variant_id]"]').val('')
      $(@wrapper).find('#cart-form button[type=submit], form[data-form-type="variant"] button[type=submit]').attr('disabled', true).fadeTo(0, 0.5)
      price = $(@wrapper).find('#product-price .price').addClass('unselected')
      # Replace product price by "(select)" only when there are at least 1 variant not out-of-stock
      variants = $(@wrapper).find("div.variant-options.index-0")
      if (variants.find(".option-value.out-of-stock").length != variants.find(".option-value").length)
        price.text('(select)')

  clear_size: (i) ->
    @variant = null
    @update(i)
    @enable_size(@buttons.removeClass('selected'))
    @toggle()
    @parent.nextAll().each (index, element) =>
      @disable($(element).find('.option-value').show().removeClass('in-stock out-of-stock').addClass('locked').unbind('click'))
    show_all_variant_images();

  clear_color: (i) ->
    @variant = null
    @update(i)
    @enable_color(@buttons.removeClass('selected'))
    @toggle()
    @parent.nextAll().each (index, element) ->
      @disable($(element).find('.option-value').show().removeClass('in-stock out-of-stock').addClass('locked').unbind('click'))
    show_all_variant_images();

  handle_size_change: (evt) ->
    @variant = null
    @selection = []
    a = $(evt.target)
    a = a.find('option[value="'+a.val()+'"]')
    @selected_option = a
    if (!@parent.has(a).length)
      @clear_size(@divs.index(a.parents('.variant-options:first')))
    @disable(@buttons);
    if (a.val() != "Select one" && !a.is('li'))
      a = @enable_size(a.addClass('selected'));
    @advance()
    if (@find_variant(@selected_option))
      @toggle();

  handle_color_change: (evt) ->
    console.log("YEE")
    if ($(evt.target).hasClass('out-of-stock'))
      return
    evt.preventDefault()
    @variant = null;
    @selection = [];
    a = $(evt.target);
    if (!@parent.has(a).length)
      @clear_color(@divs.index(a.parents('.variant-options:first')))
    @disable(@buttons)
    if (a.val() != "Select one" && !a.is('li'))
      a = @enable_size(a.addClass('selected'))
    @advance();
    if (@find_variant($(this)))
      @toggle();