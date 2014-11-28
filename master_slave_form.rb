# -*- encoding : utf-8 -*-
class MasterSlaveForm < MyForm

	attr_accessor :options, :slave_options, :rules, :messages, :html_code, :add_content
	attr_reader :xml, :slave_xml, :obj, :slave_objs, :table_name, :slave_table_name

	def initialize(master_xml,slave_xml,obj,slave_objs,master_options={},slave_options={})
		@xml = master_xml
		@slave_xml = slave_xml
		@obj = obj
		@slave_objs = slave_objs
		@options = master_options
		@slave_options = slave_options
		@table_name = obj.class.to_s.tableize
		@slave_table_name = slave_objs[0].class.to_s.tableize
		@rules = []
		@messages = []
		@html_code = ""
		@options[:grid] ||= 2 
		@options[:form_id] ||= "myform" 
    @options[:action] ||= "" 
    @options[:method] ||= "post"
    @options[:button] ||= true
    @slave_options[:title] ||= "明细"
		@slave_options[:grid] ||= 4 
	end

	def get_input_part
		tmp = super # 先调用父类中的同名方法生成master_input
		# tmp << "<div class='headline'><h2 class='heading'>#{slave_options[:title]}</h2></div>"
		tmp << "<div class='headline'><h2><strong><i class='fa fa-cubes'></i> #{slave_options[:title]}</strong></h2></div>"
		tmp << self.get_slave_input_part
		tmp << get_add_content
		return tmp
	end

	def get_slave_input_part
		self.add_content = get_add_content
  	tmp = ""
  	slave_objs.each_with_index{|o,i|tmp << get_input_content(o,i+1)}
  	return tmp
  end

  def get_add_content
  	"<div id='add_content'>#{get_input_content(slave_objs[0].class.new,'_orz_')}</div>"
  end


 	def get_total_input_part
 	end

 	private

 	def get_input_content(slave_obj,index)
  	%Q|
			<div class="tag-box tag-box-v4 details_part">
			  <button data-dismiss="alert" class="close" type="button">×</button>
			  <span rel="box-shadow-outset" class="btn-u btn-u-sm rounded-2x btn-u-default margin-bottom-20"><i class="fa  fa-chevron-circle-down"></i> #{slave_options[:title]} ##{index}</span>
			  <div class="input_part">
			  #{self.get_input_str(slave_xml,slave_obj,slave_table_name,slave_options[:grid],index)}
			  </div>
			</div>|
  end

end