module Treat
  # Makes a class delegatable, allowing calls on it to be forwarded
  # to a delegate class performing the appropriate call.
  module Delegatable
    # Add decorator methods to entities.
    def add_presets(group)
      group.presets.each do |preset_m, presets|
        define_method(preset_m) do |delegate=nil, options={}|
          options = presets.merge(options)
          m = group.method
          send(m, delegate, options)
          features[preset_m] = features.delete(m)
        end
      end
    end
    def add_preprocessors(group)
      group.preprocessors.each do |preprocessor_m, block|
        define_method(preprocessor_m) do |delegate=nil, options={}|
          block.call(self, delegate, options)
          features[preprocessor_m] = features.delete(group.method)
        end
      end
    end
    # Add decorator methods to entities.
    def add_decorators(group, m)
      group.decorators.each do |decorator_m, block|
        define_method(decorator_m) do |delegate=nil, options={}|
          options[:decorator] = decorator_m
          send(m, delegate, options)
        end
      end
    end
    # Add delegator group to all entities of a class.
    def add_delegators(group)
      # Define each method in group.
      self.class_eval do
        m = group.method
        add_presets(group)
        add_preprocessors(group)
        add_decorators(group, m)
        define_method(m) do |delegate=nil, options={}|
          decorator = options.delete(:decorator)
          if !@features[m].nil?
            @features[m]
          else
            self.class.call_delegator(
            self, m, delegate, decorator, 
            group, options)
          end
        end
      end
    end
    # Call a delegator.
    def call_delegator(entity, m, delegate, decorator, group, options)
      if delegate.nil? || delegate == :default
        delegate = get_missing_delegate(entity, group)
      end
      if not group.list.include?(delegate)
        raise Treat::Exception, delegate_not_found(delegate, group)
      else
        delegate_klass = group.const_get(cc(delegate.to_s).intern)
        result = entity.accept(group, delegate_klass, m, options)
        if decorator
          result = group.decorators[decorator].call(entity, result)
        end
        if group.type == :annotator
          f = decorator.nil? ? m : decorator
          entity.features[f] = result
        end
        result
      end
    end
    # Get the default delegate for that language
    # inside the given group.
    def get_language_delegate(language, group)
      lang = Treat::Languages.describe(language)
      lclass = cc(lang).intern
      if Treat::Languages.constants.include?(lclass)
        cat = group.to_s.split('::')[-2].intern
        lclass = Treat::Languages.const_get(lclass).const_get(cat)
        g = ucc(cl(group)).intern
        if !lclass[g] || !lclass[g][0]
          d = ucc(cl(group))
          d.gsub!('_', ' ')
          d = 'delegator to find ' + d
          raise Treat::Exception, "No #{d}" +
          " is available for the #{lang} language."
        end
        return lclass[g][0]
      else
        raise Treat::Exception,
        "Language '#{lang}' is not supported (yet)."
      end
    end
    # Get which delegate to use if none has been supplied.
    def get_missing_delegate(entity, group)
      delegate = group.default.nil? ?
      self.get_language_delegate(entity.language, group) :
      group.default
      if delegate == :none
        raise NAT::Exception,
        "There is intentionally no default delegate for #{group}."
      end
      delegate
    end
    # Return an error message and suggest possible typos.
    def delegate_not_found(klass, group)
      "Algorithm '#{ucc(klass)}' couldn't be found in group #{group}." +
      did_you_mean?(group.list.map { |c| ucc(c) }, ucc(klass))
    end
  end
end
