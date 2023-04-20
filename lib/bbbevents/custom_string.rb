class String
  # ruby mutation methods have the expectation to return self if a mutation occurred, nil otherwise. (see http://www.ruby-doc.org/core-1.9.3/String.html#method-i-gsub-21)
  # https://github.com/wycats/rails-api/blob/master/vendor/rails/activesupport/lib/active_support/inflector/methods.rb#L38-L46
  def underscore!
    gsub!(/::/, '/')
    gsub!(/([A-Z]+)([A-Z][a-z])/,'\1_\2')
    gsub!(/([a-z\d])([A-Z])/,'\1_\2')
    tr!("-", "_")
    downcase!
  end

  def underscore
    dup.tap { |s| s.underscore! }
  end
end
