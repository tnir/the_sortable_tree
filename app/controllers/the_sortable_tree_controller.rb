module TheSortableTreeController
  # include TheSortableTreeController::Rebuild
  # include TheSortableTreeController::ExpandNode
  # include TheSortableTreeController::ReversedRebuild
  
  module DefineDeprecatedMethods
    public
    def head_respond(status = :ok)
      Rails::VERSION::STRING.to_f >= 5.1 ? head(status) : render(nothing: true, status: status)
    end
  end

  module DefineVariablesMethod
    public
    def the_define_common_variables
      collection = self.class.to_s.split(':').last.sub(/Controller/,'').underscore.downcase                 # 'recipes'
      collection = self.respond_to?(:sortable_collection) ? self.sortable_collection : collection           # 'recipes'
      variable   = collection.singularize                                                                   # 'recipe'
      klass      = self.respond_to?(:sortable_model) ? self.sortable_model : variable.classify.constantize  #  Recipe
      ["@#{variable}", collection, klass]
    end
  end
  
  module ExpandNode
    include DefineVariablesMethod
    include DefineDeprecatedMethods
    def expand_node
      id   = params[:id].to_i
      return head_respond unless id
      sort = (params[:tree_sort] == 'reversed') ? 'reversed_' : nil

      variable, collection, klass = self.the_define_common_variables
      variable  = self.instance_variable_set(variable, klass.find(id))
      @children = variable.children.send("#{sort}nested_set")

      return head_respond if @children.count.zero?
      render layout: false, template: "#{collection}/expand_node"
    end
  end

  module Rebuild
    include DefineVariablesMethod
    include DefineDeprecatedMethods
    public
    def rebuild
      id = params[:id].to_i
      parent_id = params[:parent_id].to_i
      prev_id = params[:prev_id].to_i
      next_id = params[:next_id].to_i

      return head_respond(:no_content) if parent_id.zero? && prev_id.zero? && next_id.zero?

      variable, collection, klass = self.the_define_common_variables
      variable = self.instance_variable_set(variable, klass.find(id))

      begin
        ApplicationRecord.transaction do
          if prev_id.zero? && next_id.zero?
            variable.move_to_child_of klass.find(parent_id)
          elsif !prev_id.zero?
            variable.move_to_right_of klass.find(prev_id)
          elsif !next_id.zero?
            variable.move_to_left_of klass.find(next_id)
          end
          raise ActiveRecord::RecordInvalid.new(variable) unless variable.valid?
        end
      rescue ActiveRecord::RecordInvalid => e
        respond_to do |format|
          format.js { render js: "alert('#{e.message}'); window.location = '#{polymorphic_url([@ns, current_company, collection.to_sym])}'", status: 400 }
        end and return
      end

      head_respond
    end
  end
  
  module ReversedRebuild
    include DefineVariablesMethod
    include DefineDeprecatedMethods
    public
    def rebuild
      id        = params[:id].to_i
      parent_id = params[:parent_id].to_i
      prev_id   = params[:prev_id].to_i
      next_id   = params[:next_id].to_i

      return head_respond(:no_content) if parent_id.zero? && prev_id.zero? && next_id.zero?

      variable, collection, klass = self.the_define_common_variables
      variable = self.instance_variable_set(variable, klass.find(id))

      if prev_id.zero? && next_id.zero?
        variable.move_to_child_of klass.find(parent_id)
      elsif !prev_id.zero?
        variable.move_to_left_of klass.find(prev_id)
      elsif !next_id.zero?
        variable.move_to_right_of klass.find(next_id)
      end

      head_respond
    end
  end
end
