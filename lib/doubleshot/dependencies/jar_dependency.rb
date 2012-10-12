require "doubleshot/dependencies/dependency"

class Doubleshot
  class Dependencies
    class JarDependency < Dependency

      PACKAGE_TYPES = [ "pom", "jar", "maven-plugin", "ejb", "war", "ear", "rar", "par", "bundle" ]

      attr_reader :group, :artifact, :packaging, :classifier, :version
      attr_accessor :path

      def initialize(maven_coordinate)
        # This is Maven's default package type, if unspecified.
        @packaging = "jar"

        maven_coordinate_parts = maven_coordinate.split(":")
        @group = maven_coordinate_parts.shift
        @artifact = maven_coordinate_parts.shift

        if version = maven_coordinate_parts.pop
          if !PACKAGE_TYPES.include?(version)
            self.version = version
          else
            raise ArgumentError.new("Expected last coordinate part to be a Version but was a Package Type: #{maven_coordinate}")
          end
        end

        if packaging = maven_coordinate_parts.shift
          self.packaging = packaging
        end

        if classifier = maven_coordinate_parts.shift
          @classifier = classifier
        end

        @name = "#{@group}:#{@artifact}:#{@packaging}#{":#{@classifier}" if @classifier}:#{@version}"

        if [ @group, @artifact, @packaging, @version ].any? &:blank?
          raise ArgumentError.new("Invalid coordinate: #{@name}")
        end
      end

      def to_s(long_form = false)
        @name
      end

      private

      def packaging=(value = "jar")
        if PACKAGE_TYPES.include?(value.downcase)
          @packaging = value.downcase
        else
          raise ArgumentError.new("Invalid Packaging Type: #{value.inspect}")
        end
      end

      def version=(value)
        if !value.blank?
          @version = value
        else
          raise ArgumentError.new("Version must not be blank")
        end
        # compare version against rules specified here: http://www.sonatype.com/books/mvnref-book/reference/pom-relationships-sect-pom-syntax.html#pom-relationships-sect-version-build-numbers
        # http://stackoverflow.com/questions/30571/how-do-i-tell-maven-to-use-the-latest-version-of-a-dependency
      end
    end
  end
end
