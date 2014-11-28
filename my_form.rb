# -*- encoding : utf-8 -*-
class MyForm
	include ActionView::Helpers
  include MyFormHelper 

	def get_table_name(obj=self.obj)
		obj.class.to_s.tableize
	end

  def get_input_part
  	self.get_input_str
  end

  def get_input_str(xml=self.xml,obj=self.obj,table_name=self.table_name,grid=self.options[:grid],index=nil)
  	input_str = ""
  	doc = Nokogiri::XML(xml)
  	# 先生成输入框--针对没有data_type属性或者data_type属性不包括'大文本'、'富文本'、'隐藏'的
    tds = doc.xpath("/root/node[not(@data_type='textarea')][not(@data_type='richtext')][not(@data_type='hidden')][not(@display='skip')]")
    tds.each_slice(grid).with_index do |node,i|
      tmp = ""
      node.each{|n| tmp << _create_text_field(n,obj,table_name,grid,index)}
      input_str << content_tag(:div, raw(tmp).html_safe, :class=>'row')
    end
    # 再生成文本框和富文本框--针对大文本、富文本或者隐藏域
    doc.xpath("/root/node[@data_type='textarea'] | /root/node[@data_type='richtext'] | /root/node[@data_type='hidden']").each{|n|
      unless n.attributes["data_type"].to_s == "hidden"
        input_str << content_tag(:div, raw(_create_text_field(n,obj,table_name,grid,index)).html_safe, :class=>'row')
      else
        input_str << _create_text_field(n,obj,table_name,grid,index)
      end
    }
    return input_str
  end

  # 生成提交按钮
  def get_form_button(self_form=true)
    if self.options[:button]
      tmp = self_form ? self_form_button(self.class==MasterSlaveForm) : upload_form_button(self.class==MasterSlaveForm)
      return "<hr/><div>#{tmp}</div>"
    else
      return ""
    end
  end

private

  def self_form_button(is_ms_form=false)
    tmp = []
    tmp << "<button id='#{options[:form_id]}_submit' class='btn-u' type='submit'><i class='fa fa-floppy-o'></i> 保 存 </button>"
    tmp << "<button id='#{options[:form_id]}_reset' class='btn-u btn-u-default' type='reset'><i class='fa fa-repeat'></i> 重 置 </button>"
    if is_ms_form
      tmp.insert(1,"<button id='add_button' class='btn-u btn-u-blue' type='button'><i class='fa fa-plus-square'></i> 增 加 </button>")
    end
    return tmp.join(" ")
  end

  def upload_form_button(is_ms_form=false)
    tmp = []
    tmp << "<span class='btn-u' id='#{options[:form_id]}_submit'><i class='fa fa-floppy-o'></i> 保 存 </span>"
    tmp << "<span class='btn-u btn-u-default' id='#{options[:form_id]}_reset'><i class='fa fa-repeat'></i> 重 置 </span>"
    if is_ms_form 
      tmp.insert(1,"<span id='add_button' class='btn-u btn-u-blue'><i class='fa fa-plus-square'></i> 增加 </span>")
    end
    return tmp.join(" ")
  end

  # 生成输入框函数
  # /*options参数说明
  #   name  标签名称
  #   column 字段名称，有column时数据会存入相应的字段，没有时会以XML的形式存入detail字段中
  #   data_type 数据类型
  #   hint 提示信息，点击?会弹出提示框，一般比较复杂的事项、流程提醒等
  #   placeholder 输入框内提示信息
  #   display 显示方式 disabled 不可操作 readonly 是否只读 skip 跳过不出现
  #   
  # # */
  def _create_text_field(node,obj,table_name,grid,index)
    node_options = node.attributes
    # display=skip的直接跳过
    return "" if node_options.has_key?("display") && node_options["display"].to_s == "skip"
    # 生成输入框
    node_options = node.attributes
    name = node_options["name"].blank? ? "" : node_options["name"].to_str
    column = node_options["column"] || node_options["name"]
    input_opts = {} #传递参数用的哈希
    input_opts[:table_name] = table_name
    input_opts[:value] = get_node_value(obj,node,true) 
    input_opts[:icon] = get_icon(node_options)
    if node_options.has_key?("data") && !node_options["data"].blank?
      eval("input_opts[:data] = #{node_options["data"]}")
    else
      input_opts[:data] = []
    end 
    input_opts[:node_attr] = get_node_attr(table_name,node_options,column,index)
    # 主表有个性化规则
    if index.nil?
      # 校验规则
      if node_options.has_key?("rules") 
        self.rules << get_node_rules(table_name,obj,node_options,column)
      end
      # 校验提示消息
      if node_options.has_key?("messages") 
        self.messages << "'#{table_name}[#{column}]':'#{node_options["messages"]}'"
      end
    end

    # 必填字段要加上红*
    if "#{node_options["rules"]}#{node_options["class"]}".index("required")
      name << _red_text("*") 
    end
    
    # 没有标注数据类型的默认为字符
    input_opts[:data_type] = node_options.has_key?("data_type") ? node_options["data_type"].to_s : "text"
    input_opts[:hint] = (node_options.has_key?("hint") && !node_options["hint"].blank?) ? node_options["hint"] : ""
    input_str = _create_input_str(input_opts)
    if input_opts[:data_type] == "hidden"
      return input_str
    else
      result = "<label class='label'>#{name}</label>#{input_str}"
      if ["textarea","richtext"].include?(input_opts[:data_type])
        section_class = "col col-12"
      else
        section_class = "col col-#{12/grid.to_i}"
      end
      return content_tag(:section, raw(result).html_safe, :class => section_class)
    end
  end

  def _create_input_str(input_opts)
    case input_opts[:data_type]
    when "hidden"
      return _create_hidden(input_opts)
    when "radio"
      return _create_radio(input_opts)
    when "checkbox"
      return _create_checkbox(input_opts)
    when "select"
      return _create_select(input_opts)
    when "multiple_select"
      return _create_multiple_select(input_opts)
    when "textarea"
      return _create_textarea(input_opts)
    when "richtext"
      return _create_richtext(input_opts)
    else
      return _create_text(input_opts)
    end
  end

  # 红色标记的文本，例如必填项*
  def _red_text(txt)
    return raw "<span class='text-red'>#{txt}</span>".html_safe
  end

  def get_icon(node_options)
    if node_options.has_key?("class")
      tmp = node_options["class"].to_str.split(" ")
      if !(["tree_checkbox","tree_radio","box_checkbox","box_radio"] & tmp).blank?
        default_icon = "chevron-down"
      elsif !(["date_select"] & tmp).blank?
        default_icon = "calendar"
      end
    end
    
    return node_options.has_key?("icon") ? node_options["icon"] : (default_icon || "info")
  end

  def get_node_attr(table_name,node_options,column,index)
    opt = []
    if index.nil? # 主表
      opt << "name='#{table_name}[#{column}]'"
      opt << "id='#{table_name}_#{column}'"
      opt << "partner='#{table_name}_#{node_options["partner"]}'" if node_options.has_key?("partner")
    else # 从表
      opt << "name='#{table_name}[#{column}][#{index}]'"
      opt << "id='#{table_name}_#{column}_#{index}'"
      opt << "partner='#{table_name}_#{node_options["partner"]}_#{index}'" if node_options.has_key?("partner")
    end
    opt << "disabled='disabled'" if node_options.has_key?("display") && node_options["display"].to_s == "disabled"
    opt << "readonly='readonly'" if node_options.has_key?("display") && node_options["display"].to_s == "readonly"
    opt << "placeholder='#{node_options["placeholder"]}'" if node_options.has_key?("placeholder")
    opt << "class='#{node_options["class"]}'" if node_options.has_key?("class")
    opt << "json_url='#{node_options["json_url"]}'" if node_options.has_key?("json_url")
    opt << "limited='#{node_options["limited"]}'" if node_options.has_key?("limited")
    return opt
  end

  def get_node_rules(table_name,obj,node_options,column)
    # 判断有ajax校验的情况，增加当前节点的ID作为判断参数
    if node_options["rules"].to_s.include?("remote")
      hash_rules = eval(node_options["rules"].to_s)
      hash_remote = hash_rules[:remote]
      if hash_remote.has_key?(:data) 
        hash_remote[:data][:obj_id] = obj.id unless obj.id.nil?
      else
        hash_remote[:data] = {obj_id: obj.id} unless obj.id.nil?
      end
      node_options["rules"] = hash_to_string(hash_rules)
    end
    return "'#{table_name}[#{column}]':#{node_options["rules"]}"
  end

  # 样式是否只读
  def _form_states(input_style,opt)
    return (opt & ["disabled='disabled'","readonly='readonly'"]).empty? ? input_style : "#{input_style} state-disabled"
  end

# 隐藏输入框
  def _create_hidden(input_opts)
    return "<input type='hidden' #{input_opts[:node_attr].join(" ")} value='#{input_opts[:value]}' />"
  end
  # 普通文本
  def _create_text(input_opts)
    str = %Q|
    <label class='#{_form_states('input',input_opts[:node_attr])}'>
        <i class="icon-append fa fa-#{input_opts[:icon]}"></i>
        <input type='text' value='#{input_opts[:value]}' #{input_opts[:node_attr].join(" ")}>
        #{input_opts[:hint].blank? ? "" : "<b class='tooltip tooltip-bottom-right'>#{input_opts[:hint]}</b>"}
    </label>|
  end
  # 单选
  def _create_radio(input_opts)
    data_str = ""
    form_state = _form_states('radio',input_opts[:node_attr]) 
    input_opts[:data].each do |d|
      options = input_opts[:node_attr].clone
      if d.is_a?(Array) 
        options << "checked" if (input_opts[:value] && input_opts[:value] == d[0])
        data_str << "<label class='#{form_state}'><input type='radio' value='#{d[0]}' #{options.join(" ")}><i class='rounded-x'></i>#{d[1]}</label>\n"
      else
        options << "checked" if (input_opts[:value] && input_opts[:value] == d)
        data_str << "<label class='#{form_state}'><input type='radio' value='#{d}' #{options.join(" ")}><i class='rounded-x'></i>#{d}</label>\n"
      end
    end
    str = %Q|
    <div class="inline-group">
        #{data_str}
    </div>
    #{input_opts[:hint].blank? ? '' : "<div class='note'><strong>提示:</strong> #{input_opts[:hint]}</div>" }|
  end
  # 多选
  def _create_checkbox(input_opts)
    data_str = ""
    form_state = _form_states('checkbox',input_opts[:node_attr])
    input_opts[:data].each do |d| 
      options = input_opts[:node_attr].clone
      if d.is_a?(Array)
        options << "checked" if (input_opts[:value] && input_opts[:value].split(",").include?(d[0]))
        data_str << "<label class='#{form_state}'><input type='checkbox' value='#{d[0]}' #{options.join(" ")}><i></i>#{d[1]}</label>\n"
      else
        options << "checked" if (input_opts[:value] && input_opts[:value].split(",").include?(d))
        data_str << "<label class='#{form_state}'><input type='checkbox' value='#{d}' #{options.join(" ")}><i></i>#{d}</label>\n"
      end
    end
    str = %Q|
    <div class="inline-group">
        #{data_str}
    </div>
    #{input_opts[:hint].blank? ? '' : "<div class='note'><strong>提示:</strong> #{input_opts[:hint]}</div>" }|
  end
  # 下拉单选
  def _create_select(input_opts)
    data_str = "<option value=''>请选择...</option>\n"
    form_state = _form_states('select',input_opts[:node_attr])
    input_opts[:data].each do |d| 
      if d.is_a?(Array)
        checked = (input_opts[:value] && input_opts[:value] == d[0]) ? 'selected' : ''
        data_str << "<option value='#{d[0]}' #{checked}>#{d[1]}</option>\n"
      else
        checked = (input_opts[:value] && input_opts[:value] == d) ? 'selected' : ''
        data_str << "<option value='#{d}' #{checked}>#{d}</option>\n"
      end
    end
    str = %Q|
    <label class='#{form_state}'>
      <select #{input_opts[:node_attr].join(" ")}>
        #{data_str}
      </select>
    </label>
    #{input_opts[:hint].blank? ? '' : "<div class='note'><strong>提示:</strong> #{input_opts[:hint]}</div>" }|
  end
  # 下拉多选
  def _create_multiple_select(input_opts)
    data_str = ""
    form_state = _form_states('select select-multiple',input_opts[:node_attr])
    input_opts[:data].each do |d| 
      if d.is_a?(Array)
        checked = (input_opts[:value] && input_opts[:value].split(",").include?(d[0])) ? 'selected' : ''
        data_str << "<option value='#{d[0]}' #{checked}>#{d[1]}</option>\n"
      else
        checked = (input_opts[:value] && input_opts[:value].split(",").include?(d)) ? 'selected' : ''
        data_str << "<option value='#{d}' #{checked}>#{d}</option>\n"
      end
    end
    str = %Q|
    <label class='#{form_state}'>
      <select multiple #{input_opts[:node_attr].join(" ")}>
        #{data_str}
      </select>
    </label>
    <div class='note'><strong>提示:</strong> #{input_opts[:hint].blank? ? '按住ctrl键可以多选。' : "#{input_opts[:hint]}；按住ctrl键可以多选。" }</div>|
  end
  # 大文本
  def _create_textarea(input_opts)
    form_state = _form_states('textarea textarea-resizable',input_opts[:node_attr])
    str = %Q|
    <label class='#{form_state}'>
      <textarea class='autosize form-control' rows='2' #{input_opts[:node_attr].join(" ")}>#{input_opts[:value]}</textarea>
    </label>
    #{input_opts[:hint].blank? ? '' : "<div class='note'><strong>提示:</strong> #{input_opts[:hint]}</div>" }|
  end
  # 富文本
  def _create_richtext(input_opts)
    form_state = _form_states('textarea textarea-resizable',input_opts[:node_attr])
    str = %Q|
    <label class='#{form_state}'>
      <textarea class='autosize form-control' rows='2' #{input_opts[:node_attr].join(" ")}>#{input_opts[:value]}</textarea>
    </label>
    #{input_opts[:hint].blank? ? '' : "<div class='note'><strong>提示:</strong> #{input_opts[:hint]}</div>" }|
  end


end