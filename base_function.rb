# -*- encoding : utf-8 -*-
module BaseFunction

# 获取某实例的字段值
def get_node_value(obj,node,for_form=false)
    # 父节点特殊处理
    if obj.attributes.include?("ancestry")
    	return obj.parent_id if node["name"] == "parent_id" 
    	return obj.parent_name if node["name"] == "父节点名称"
    end
    # 一般情况
    result = ""
    if node.attributes.has_key?("column") && obj.class.attribute_method?(node["column"])
    	result = obj.attributes[node["column"]]
    else
    	if obj.class.attribute_method?("details") && !obj.attributes["details"].blank?
    		doc = Nokogiri::XML(obj["details"])
    		tmp = doc.xpath("/root/node[@name='#{node["name"]}']").first
    		result = tmp.blank? ? "" : tmp["value"]
    	end
    end
    return transform_node_value(node,result,for_form)
  end

  # 如果是二维数组的选择类型的，需要转换KEY和VALUE
  def transform_node_value(node,result,for_form=false)
    unless for_form 
      if node.attributes.has_key?("data") 
        arr = eval(node.attributes["data"].to_str)
        if arr[0].is_a?(Array)
          tmp = arr.find{|d|d[0] == tranform_boolean(result,true)}
          result = tmp[1] unless tmp.blank?
        end
      end
    else
      result = tranform_boolean(result,for_form)
    end
    return result
  end

  # 对布尔型进行转换，在form里要显示数字--1或0，在show时要显示中文--是或否
  def tranform_boolean(s,show_num=true)
    if show_num
      if s == true || s.to_s == "1"
        return 1 
      elsif s == false || s.to_s == "0"
        return 0
      else
        return s
      end
    else
      if s == true || s.to_s == "1"
        return "是"
      elsif s == false || s.to_s == "0"
        return "否"
      else
        return s
      end
    end
  end

  # 哈希转成syml格式的字符串，供JS调用
  def hash_to_string(ha)
  	if ha.is_a?(Hash)
  		arr = []
  		ha.each do |key,value|
  			arr << "#{key}:#{hash_to_string(value)}"
  		end
  		return "{#{arr.join(',')}}"
  	elsif ha.is_a?(String)
  		return "'#{ha}'"
  	else
  		return ha
  	end
  end

  # 显示obj记录的信息
  def show_obj_info(obj,xml,options={})
    grid = options.has_key?(:grid) ? options[:grid] : 2
    str = ""
    tbody = ""
    if options.has_key?(:title) && !options[:title].blank?
      str << "<h5><i class='fa fa-chevron-circle-down'></i> #{options[:title]}</h5>"
    else
      str << "<br />"
    end 
    doc = Nokogiri::XML(xml)
    # 先生成输入框--针对没有data_type属性或者data_type属性不包括'大文本'、'富文本'的
    tds = doc.xpath("/root/node[not(@data_type='textarea')][not(@data_type='richtext')][not(@data_type='hidden')][not(@display='skip')]")
    tds.each_slice(grid).with_index do |node,i|
      tbody << "<tr>"
      node.each_with_index{|n,ii|
        tbody << "<td>#{n.attributes["name"]}</td><td>#{get_node_value(obj,n)}</td>"
        tbody << "<td></td><td></td>" * (grid-ii-1) if (n == node.last) && (ii != grid -1)
      }
      tbody << "</tr>"
    end
    # 再生成文本框和富文本框--针对大文本或者富文本
    doc.xpath("/root/node[contains(@data_type,'text')]").each_slice(1) do |node|
      node.each{|n|
        tbody << "<tr>"
          tbody << "<td>#{n.attributes["name"]}</td><td colspan='#{grid*2-1}'>#{get_node_value(obj,n)}</td>"
        tbody << "</tr>"
      }
    end

    str << "<div class='show_obj'><table class='table table-striped table-bordered'><tbody>#{tbody}</tbody></table></div>"
    return str.html_safe
  end

  # 显示评价记录 -- 订单或产品 
  def show_estimates(obj)
    something_not_found
  end

  # 显示记录的操作日志
  def show_logs(obj)
    return "暂无记录" if obj.logs.blank?
    str = []
    doc = Nokogiri::XML(obj.logs)
    doc.xpath("/root/node").each do |n|
      opt_time = n.attributes["操作时间"].to_s.split(" ")
      act = n.attributes["操作内容"].to_s[0,2]
      infobar = []
      infobar << "状态:#{obj.status_badge(n.attributes["当前状态"].to_str.to_i)}" if n.attributes.has_key?("当前状态")
      infobar << "姓名:#{n.attributes["操作人姓名"]}"
      infobar << "ID:#{n.attributes["操作人ID"]}"
      infobar << "单位:#{n.attributes["操作人单位"]}"
      infobar << "IP地址:#{n.attributes["IP地址"]}"
      str << %Q|
      <li>
        <time class='cbp_tmtime' datetime=''><span>#{opt_time[1]}</span> <span>#{opt_time[0]}</span></time>
        <i class='cbp_tmicon rounded-x hidden-xs'></i>
        <div class='cbp_tmlabel'>
          <h4><i class="fa fa-chevron-circle-right"></i> #{obj.icon_action(n.attributes["操作内容"].to_str,false)}</h4>
          <div style="display:none;">#{n.attributes["备注"]}</div>
          <p>#{infobar.join("&nbsp;&nbsp;")}</p>
        </div>
      </li>|
    end
    return "<ul class='timeline-v2'>#{str.reverse.join}</ul>"
  end

  # 显示附件
  def show_uploads(obj,picture=false,grid=4)
    return something_not_found if obj.uploads.blank?
    result = ""
    # 图片类型
    if picture
      tmp = obj.uploads.map do |file|
        %Q|<div class="col-md-#{12/grid}"><div class="thumbnails thumbnail-style thumbnail-kenburn">
            <a href="#{file.upload.url(:original)}" title="#{file.upload_file_name}" data-rel="fancybox-button" class="fancybox-button zoomer">
              <span class="overlay-zoom overflow-hidden">  
                <img alt="" src="#{file.upload.url(:md)}" class="img-responsive">
                <span class="zoom-icon"></span>                   
              </span>                                              
            </a>
            <div class="caption">
              <p class="word_break">#{file.upload_file_name}<br>[#{number_to_human_size(file.upload_file_size)}]</p>
            </div>                  
          </div></div>|.html_safe
      end
    # 非图片类型
    else
      tmp = obj.uploads.map do |file|
        %Q|<div class="col-md-#{12/grid}">
          <div class="servive-block servive-block-default">
            <a href="#{file.upload.url(:original)}" title="#{file.upload_file_name}" target="_blank">
              <img alt="" src="#{file.to_jq_upload["thumbnail_url"]}">
              <p class="word_break">#{file.upload_file_name}<br>[#{number_to_human_size(file.upload_file_size)}]</p>
            </a>                          
          </div>
        </div>|.html_safe
      end
    end
    tmp.each_slice(grid) do |t|
      result << "<div class='row'>#{t.join}</div>"
    end
    return result.html_safe
  end

  # 生成随机数
  def create_random_chars(len)
    chars = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a
    tmp = ""
    1.upto(len) {|i| tmp << chars[rand(chars.size-1)]}
    return tmp
  end

  def something_not_found
    "<div class='alert alert-danger fade in'><h4><i class='fa fa-frown-o font_24px'></i> 抱歉，没有找到相关信息。</h4></div>"
  end

  #  截取字符串固定长度，支持中英文混合，length 为中文的长度，一个英文相当于0.5个中文长度
  def text_truncate(text, length = 30, truncate_string = "...")
    if text
      l=0
      char_array=text.unpack("U*")
      char_array.each_with_index do |c,i|
        l = l+ (c<127 ? 0.5 : 1)
        if l>=length
          return char_array[0..i].pack("U*")+(i ? truncate_string : "")
        end
      end
      return text
    else
      return ""
    end
  end

end