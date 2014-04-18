# ![](https://raw.github.com/aptible/straptible/master/lib/straptible/rails/templates/public.api/icon-60px.png) Aptible::Resource

[![Gem Version](https://badge.fury.io/rb/aptible-resource.png)](https://rubygems.org/gems/aptible-resource)
[![Build Status](https://travis-ci.org/aptible/aptible-resource.png?branch=master)](https://travis-ci.org/aptible/aptible-resource)
[![Dependency Status](https://gemnasium.com/aptible/aptible-resource.png)](https://gemnasium.com/aptible/aptible-resource)

Foundation classes for Aptible resource server gems.

## Usage

To build a new resource server gem on top of `aptible-resource`, create a top-level class for your resource server. For example:

```ruby
module Example
  module Api
    class Resource < Aptible::Resource::Base
      def namespace
        'Example::Api'
      end

      def root_url
        'https://api.example.com'
      end
    end
  end
end
```

Then add the gem to your gemspec:

```ruby
spec.add_dependency 'aptible-resource'
```

## Development

This gem depends on a vendored version of [HyperResource](https://github.com/gamache/hyperresource), which can be updated from a local checkout of HyperResource as follows:

    cp -rp /path/to/hyperresource/lib/hyper_resource* lib/

## Contributing

1. Fork the project.
1. Commit your changes, with specs.
1. Ensure that your code passes specs (`rake spec`) and meets Aptible's Ruby style guide (`rake rubocop`).
1. Create a new pull request on GitHub.

## Copyright and License

MIT License, see [LICENSE](LICENSE.md) for details.

Copyright (c) 2014 [Aptible](https://www.aptible.com), Frank Macreery, and contributors.
