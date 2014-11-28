# -*- encoding : utf-8 -*-
module SaveXmlForm
  include BaseFunction
  include ActionView::Helpers::NumberHelper # number_to_human_size 函数

  # 创建主从表并写日志
  def create_msform_and_write_logs(master,master_xml,slave,slave_xml,title={},other_attrs={})
    other_attrs = set_default_column(master,other_attrs)
    title[:action] ||= "录入数据"
    title[:master_title] ||= "基本信息"
    title[:slave_title] ||= "明细信息"
    attribute = prepare_params_for_save(master,master_xml,other_attrs) # 获取并整合主表参数信息
    master_obj = master.create(attribute) #保存主表
    unless master_obj.errors.messages.blank?
      flash_get master_obj.errors.messages[:base]
      return master_obj
    else
      logs_remark = prepare_origin_logs_remark(master,master_xml,title[:master_title]) #主表日志
      logs_remark << save_uploads(master_obj) # 保存附件并将日志添加到主表日志
      logs_remark << save_slaves(master_obj,slave,slave_xml,title[:slave_title]) # 保存从表并将日志添加到主表日志
      unless logs_remark.blank?
        write_logs(master_obj,title[:action],logs_remark) # 写日志
      end
      return master_obj
    end
  end

  # 更新主从表并写日志
  def update_msform_and_write_logs(master_obj,master_xml,slave,slave_xml,title={},other_attrs={})
    title[:action] ||= "修改数据"
    title[:master_title] ||= "基本信息"
    title[:slave_title] ||= "明细信息"
    attribute = prepare_params_for_save(master_obj.class,master_xml,other_attrs) # 获取并整合主表参数信息
    logs_remark = prepare_edit_logs_remark(master_obj,master_xml,"修改#{title[:master_title]}") #主表日志--修改痕迹 先取日志再更新主表，否则无法判断修改前后的变化情况
    save_uploads(master_obj) # 保存附件,附件日志已经在文件上传时记录了
    master_obj.update_attributes(attribute) #更新主表
    logs_remark << save_slaves(master_obj,slave,slave_xml,title[:slave_title]) # 保存从表并将日志添加到主表日志
    unless logs_remark.blank?
      write_logs(master_obj,title[:action],logs_remark) # 写日志
    end
    return master_obj
  end

  #创建并写日志
  def create_and_write_logs(model,xml,title={},other_attrs={})
    other_attrs = set_default_column(model,other_attrs)
    title[:action] ||= "录入数据"
    title[:master_title] ||= "详细信息"
    attribute = prepare_params_for_save(model,xml,other_attrs)
    obj = model.create(attribute)
    logs_remark = prepare_origin_logs_remark(model,xml,title[:master_title]) #主表日志
    logs_remark << save_uploads(obj) # 保存附件并将日志添加到主表日志
    unless logs_remark.blank?
      write_logs(obj,title[:action],logs_remark) # 写日志
    end
    return obj
  end

  #更新并写日志
  def update_and_write_logs(obj,xml,title={},other_attrs={})
    title[:action] ||= "修改数据"
    title[:master_title] ||= "详细信息"
    attribute = prepare_params_for_save(obj.class,xml,other_attrs)
    logs_remark = prepare_edit_logs_remark(obj,xml,"修改#{title[:master_title]}") #主表日志--修改痕迹 先取日志再更新主表，否则无法判断修改前后的变化情况
    save_uploads(obj) # 保存附件，附件日志已经上文件上传时记录了
    obj.update_attributes(attribute) #更新主表
    unless logs_remark.blank?
      write_logs(obj,title[:action],logs_remark) # 写日志
    end
    return obj
  end

  #  手动写入日志 确保表里面有logs和status字段才能用这个函数
  def write_logs(obj,action,remark='')
    doc = prepare_logs_content(obj,action,remark)
    obj.update_columns("logs" => doc)
  end

  # 准备参数，column参数存到字段中，非column参数存到details中,other_attrs 是其他人为赋值字段
  def prepare_params_for_save(model,xml,other_attrs={})
    tmp = get_xmlform_params(model,xml)
    result = tmp[0]
    unless tmp[1].blank?
      result["details"] = prepare_details(tmp[1]) if model.attribute_method?(:details)
      result["parent_id"] = tmp[1]["parent_id"] if tmp[1].has_key?("parent_id")
    end
    return result.update(other_attrs)
  end

  # 批量操作要替换的日志
  def batch_logs(action,remark='')
    remark = remark.blank? ? "来自批量操作" : "#{remark}[来自批量操作]"
    return %Q|<node 操作时间="#{Time.new.to_s(:db)}" 操作人ID="#{current_user.id}" 操作人姓名="#{current_user.name}" 操作人单位="#{current_user.department.nil? ? "暂无" : current_user.department.name}" 操作内容="#{action}" 当前状态="$STATUS$" 备注="#{remark}" IP地址="#{request.remote_ip}[#{IPParse.parse(request.remote_ip).gsub("Unknown", "未知")}]"/>|
  end

  # 生成XML 用于品目参数维护 返回XML
  def create_xml(xml,model)
    column_arr = Nokogiri::XML(xml).xpath("/root/node[@column]").map{ |node| node.attributes["column"].to_str }
    doc = Nokogiri::XML::Document.new
    doc.encoding = "UTF-8"
    doc << "<root>"
    params_arr = params.require(model.to_s.tableize.to_sym)
    params_arr["name"].keys.each do |i|
      node = doc.root.add_child("<node>").first
      rule = []
      column_arr.each do |column|
        next if params_arr[column].blank? || params_arr[column][i].blank?
        value = params_arr[column][i]
        case column
        when "data"
          node[column] = value.split("|") 
        when "is_required"
          rule << "required" if value == "1"
        when "rule"
          rule << value
          rule << "date_select" if ["dateISO", "date"].include?(value)
        else
          node[column] = value
        end
      end
      node["class"] = rule.join(" ") unless rule.blank?
    end
    return doc.to_s
  end

  # 从XML中生成model的n个实例 返回数组
  def create_objs_from_xml_model(xml,model)
    arr = []
    rule_arr = Dictionary.inputs.rule.map(&:first)
    Nokogiri::XML(xml).xpath("/root/node").each do |node|
      obj = model.new
      node.attributes.each do |key, value|
        case key
        when "data"
          obj.attributes[key] = eval(value.to_str).join("|") unless value.blank?
        when "class"
          cls_arr = value.to_str.split(" ")
          obj.attributes["is_required"] = cls_arr.include?("required")
          obj.attributes["rule"] = (cls_arr & rule_arr)[0]
        else
          obj.attributes[key] = value.to_str
        end
      end
      arr << obj
    end
    return arr
  end

private

  #XML_FORM表单提交后生成的参数，返回二维数组，第一维是存入数据库的column参数，第二维是拼成details的name参数
  def get_xmlform_params(model,xml)
    tmp = get_column_and_name_array(model,xml)
    return [params.require(model.to_s.tableize.to_sym).permit(tmp[0]) ,params.require(model.to_s.tableize.to_sym).permit(tmp[1])]
  end

  # 返回二维数组，第一维是存入数据库的column参数，第二维是拼成details的name参数
  def get_column_and_name_array(model,xml)
    column_params = []
    name_params = []
    doc = Nokogiri::XML(xml)
    doc.xpath("/root/node").each{|node|
      if node.attributes.has_key?("column")
        column_params << node.attributes["column"].to_s
      else
        name_params << node.attributes["name"].to_s
      end
    }
    return [column_params,name_params]
  end

  #根据XML_FORM表单提交后的参数准备好details的XML文档
  def prepare_details(data)
    doc = Nokogiri::XML::Document.new
    doc.encoding = "UTF-8"
    doc << "<root>"
    data.each do |key,value|
      next if ["parent_id","父节点名称"].include?(key)
      node = doc.root.add_child("<node>").first
      node["name"] = key
      node["value"] = value
    end
    return doc.to_s
  end

  # 准备日志的内容
  def prepare_logs_content(obj,action,remark='')
    user = current_user
    unless obj.logs.nil?
      doc = Nokogiri::XML(obj.logs)
    else
      doc = Nokogiri::XML::Document.new()
      doc.encoding = "UTF-8"
      doc << "<root>"
    end
    node = doc.root.add_child("<node>").first
    node["操作时间"] = Time.now.to_s(:db)
    node["操作人ID"] = user.id.to_s
    node["操作人姓名"] = user.name.to_s
    node["操作人单位"] = user.department.nil? ? "暂无" : user.department.name.to_s
    node["操作内容"] = action
    node["当前状态"] = (!obj.attribute_names.include?("status") || obj.status.nil?) ? "-" : obj.status
    node["备注"] = remark
    node["IP地址"] = "#{request.remote_ip}|#{IPParse.parse(request.remote_ip).gsub("Unknown", "未知")}"
    return doc.to_s
  end

  # 准备创建纪录时的原始日志
  def prepare_origin_logs_remark(model,xml,title='详细信息',all_params={})
    all_params = params.require(model.to_s.tableize.to_sym) if all_params.length == 0
    spoor = ""
    doc = Nokogiri::XML(xml)
    doc.xpath("/root/node").each{|node|
      attr_name = node.attributes.has_key?("name") ? node.attributes["name"] : node.attributes["column"]
      if node.attributes.has_key?("column")
        new_value = all_params[node.attributes["column"].to_str]
      else
        new_value = all_params[node.attributes["name"].to_str]
      end 
      new_value = transform_node_value(node,new_value)
      spoor << "<tr><td>#{attr_name.to_str}</td><td>#{new_value}</td></tr>" unless new_value.to_s.blank?
    }
    if spoor.blank?
      return ""
    else
      return %Q|<div class="headline"><h3 class="heading-sm">#{title}</h3></div><table class='table table-bordered'><thead><tr><th>参数名称</th><th>参数值</th></tr></thead><tbody>#{spoor}</tbody></table>|.html_safe.to_str
    end
  end

  # 准备修改纪录时的痕迹纪录
  def prepare_edit_logs_remark(obj,xml,title='修改痕迹',all_params={})
    all_params = params.require(obj.class.to_s.tableize.to_sym) if all_params.length == 0
    spoor = ""
    doc = Nokogiri::XML(xml)
    doc.xpath("/root/node").each{|node|
      attr_name = node.attributes.has_key?("name") ? node.attributes["name"] : node.attributes["column"]
      if node.attributes.has_key?("column")
        new_value = all_params[node.attributes["column"].to_str]
      else
        new_value = all_params[node.attributes["name"].to_str]
      end 
      new_value = transform_node_value(node,new_value)
      old_value = get_node_value(obj,node)
      spoor << "<tr><td>#{attr_name.to_str}</td><td>#{old_value}</td><td>#{new_value}</td></tr>" unless old_value.to_s == new_value.to_s || new_value.nil?
    }
    if spoor.blank?
      return ""
    else
      return %Q|<div class="headline"><h3 class="heading-sm">#{title}</h3></div><table class='table table-bordered'><thead><tr><th>参数名称</th><th>修改前</th><th>修改后</th></tr></thead><tbody>#{spoor}</tbody></table>|.html_safe.to_str
    end
  end

  # 下面两个方法暂时不用,single form 的日志暂时用prepare_origin_logs_remark 来代替

  # # 获取SingleForm创建时的原始数据
  # def get_single_origin_data(model)
  #   logs_remark = prepare_origin_logs_remark(model)
  #   unless logs_remark.blank?
  #     return prepare_logs_content(model.new,"录入数据",logs_remark)
  #   else
  #     return nil
  #   end
  # end

  # # 获取SingleForm修改痕迹
  # def get_single_edit_spoor(obj)
  #   logs_remark = prepare_edit_logs_remark(obj)
  #   unless logs_remark.blank?
  #     return prepare_logs_content(obj,"修改数据",logs_remark)
  #   else
  #     return nil
  #   end
  # end

  # 保存从表数据
  def save_slaves(master_obj,slave,slave_xml,slave_title="数据")
    logs_remark = "" # 从表不纪录日志,日志纪录到主表中去
    slave_params = params.require(slave.to_s.tableize.to_sym)
    foreign_key = "#{master_obj.class.to_s.underscore}_id"
    # 数据库中原来存在的从表记录
    tables_ids = slave.where(["#{foreign_key} = ?", master_obj.id]).map(&:id)
    column_name = get_column_and_name_array(slave, slave_xml)
    # 参数的高度即slava的数量,预设必须有ID这个参数
    slave_params["id"].keys.each do |i|
      attribute = {}
      details = {}
      column_name[0].each{|column| attribute[column] = slave_params[column][i]}
      column_name[1].each{|name| details[name] = slave_params[name][i]}
      all_params = attribute.merge details # 分析日志用的参数
      attribute["details"] = prepare_details(details)
      if attribute["id"].blank?
        attribute[foreign_key] = master_obj.id #主键
        attribute.delete("id")
        obj = slave.create(attribute)
        logs_remark << prepare_origin_logs_remark(slave,slave_xml,"添加#{slave_title}##{obj.id}",all_params)
      else
        obj = slave.find(attribute["id"])
        logs_remark << prepare_edit_logs_remark(obj,slave_xml,"修改#{slave_title}##{obj.id}",all_params)
        obj.update_attributes(attribute)
      end
    end
    # 参数中存在的ID，即原数据库中没有被删除的
    exists_ids = slave_params["id"].values.delete_if{|x|x == ""}.map{|x|x.to_i}
    delete_ids = tables_ids - exists_ids
    unless delete_ids.blank?
      slave.delete(delete_ids) # 删除部分从表记录
      logs_remark << %Q|<div class="alert alert-danger fade in">删除#{slave_title} ##{delete_ids.join(" #")}</div>|.html_safe.to_str
    end
    return logs_remark
  end

  # 保存附件
  def save_uploads(obj)
    unless params["uploaded_file_ids"].blank?
      uploads = obj.class.upload_model.where(master_id: 0, id: params["uploaded_file_ids"].split(","))
      unless uploads.blank?
        obj.uploads << uploads
        logs_remark = '<div class="headline"><h3 class="heading-sm">上传附件</h3></div>'
        logs_remark << prepare_upload_logs_remark(uploads)
        return logs_remark
      else
        return ""
      end
    else
      return ""
    end
  end

  # 保存数据时设置默认字段
  def set_default_column(model,other_attrs)
    if model.attribute_names.include?("user_id")
      return other_attrs.update({user_id: current_user.id}) # 当前用户
    else
      return  other_attrs
    end
  end

  # 上传附件时记录的日志信息
  def prepare_upload_logs_remark(uploads,action="create")
    style = action == "create" ? "alert-success" : "alert-danger"
    return %Q|<div class="alert #{style} fade in">#{uploads.map{|u|"#{u.upload_file_name} [#{number_to_human_size(u.upload_file_size)}]"}.join("<br>")}</div>|.html_safe.to_str
  end

end