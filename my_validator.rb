class MyValidator < ActiveModel::Validator
  def validate(record)
    Nokogiri::XML(record.class.xml).xpath("/root/node[@class]").each do |node|
      attr = node.attributes["class"].to_str
      if attr.index("required")
        record.errors[:base] << "#{node.attributes["name"]}不能为空" if is_required?(attr_value(node,record))
      elsif attr.index("dateISO")
        record.errors[:base] << "#{node.attributes["name"]}必须是日期类型" if is_date?(attr_value(node,record))
      elsif attr.index("email")
        record.errors[:base] << "#{node.attributes["name"]}必须是email类型" if is_email?(attr_value(node,record))
      end
    end
  end

  private 

  # 获取节点属性的值
  def attr_value(node,record)
    if node.attributes.has_key?("column")
      return record.send(node.attributes["column"].to_str)
    else
      return record.details[node.attributes["name"].to_str] if record.details
    end
  end

  def is_required?(s)
    return s.blank?
  end

  def is_email?(s)
    return /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i.match(s)
  end

  def is_date?(s)
  end

  def is_url?(s)
  end

  def is_number?(s)
  end

  # 请对应form.js的校验函数来完善
    # required: {required: true},
    # email: {email: true},
    # url: {url: true},
    # date: {date: true},
    # dateISO: {dateISO: true}, 
    # number: {number: true},
    # digits: {digits: true},  
    # minlength_6: {minlength: 6},
    # maxlength_800: {maxlength: 800},
    # rangelength_6_20: {rangelength: [6,20]},
    # min_1: {min: 1},
    # max_100: {max: 100},
    # range_1_1000: {range: [1,1000]}
end