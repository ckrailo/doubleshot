class Doubleshot
  class Resolver
    class GemResolver
      class Graph
        # Create a key for a graph from an instance of an Artifact or Dependency
        #
        # @param [Doubleshot::Resolver::GemResolver::Artifact, Doubleshot::Resolver::GemResolver::Dependency] object
        #
        # @raise [ArgumentError] if an instance of an object of an unknown type is given
        #
        # @return [Symbol]
        def self.key_for(object)
          case object
          when Doubleshot::Resolver::GemResolver::Artifact
            artifact_key(object.name, object.version)
          when Doubleshot::Resolver::GemResolver::Dependency
            dependency_key(object.name, object.constraint)
          else
            raise ArgumentError, "Could not generate graph key for Class: #{object.class}"
          end
        end

        # Create a key representing an artifact for an instance of Graph
        #
        # @param [#to_s] name
        # @param [#to_s] version
        #
        # @return [Symbol]
        def self.artifact_key(name, version)
          "#{name}-#{version}".to_sym
        end

        # Create a key representing an dependency for an instance of Graph
        #
        # @param [#to_s] name
        # @param [#to_s] constraint
        #
        # @return [Symbol]
        def self.dependency_key(name, constraint)
          "#{name}-#{constraint}".to_sym
        end

        def initialize(*repositories)
          @sources   = repositories.map do |repository|
            Source.new(repository)
          end
          @versions  = Hash.new
          @artifacts = Hash.new
        end

        # @overload artifacts(name, version)
        #   Return the Doubleshot::Resolver::GemResolver::Artifact from the collection of artifacts
        #   with the given name and version.
        #
        #   @param [#to_s]
        #   @param [Gem::Version, #to_s]
        #
        #   @return [Doubleshot::Resolver::GemResolver::Artifact]
        # @overload artifacts
        #   Return the collection of artifacts
        #
        #   @return [Array<Doubleshot::Resolver::GemResolver::Artifact>]
        def artifacts(*args)
          if args.empty?
            return artifact_collection
          end
          unless args.length == 2
            raise ArgumentError, "Unexpected number of arguments. You gave: #{args.length}. Expected: 0 or 2."
          end

          name, version = args

          if name.nil? || version.nil?
            raise ArgumentError, "A name and version must be specified. You gave: #{args}."
          end

          artifact = Artifact.new(self, name, version)
          add_artifact(artifact)
        end

        # Return all the artifacts from the collection of artifacts
        # with the given name.
        #
        # @param [String] name
        #
        # @return [Array<Doubleshot::Resolver::GemResolver::Artifact>]
        def versions(name, constraint = ">= 0.0.0")
          constraint = constraint.is_a?(Gem::Requirement) ? constraint : Gem::Requirement.new(constraint)

          if @sources.empty?
            # ORIGINAL CODE FROM Solve PROJECT. DO NOT TOUCH!
            artifacts.select do |artifact|
              artifact.name == name && constraint.satisfied_by?(artifact.version)
            end
          else
            @sources.map do |source|
              source.versions(name).select do |version|
                constraint.satisfied_by?(version)
              end.map do |version|
                Artifact.new(self, name, version)
              end
            end.flatten
          end
        end

        # Add a Doubleshot::Resolver::GemResolver::Artifact to the collection of artifacts and
        # return the added Doubleshot::Resolver::GemResolver::Artifact. No change will be made
        # if the artifact is already a member of the collection.
        #
        # @param [Doubleshot::Resolver::GemResolver::Artifact] artifact
        #
        # @return [Doubleshot::Resolver::GemResolver::Artifact]
        def add_artifact(artifact)
          unless has_artifact?(artifact.name, artifact.version)
            @artifacts[self.class.key_for(artifact)] = artifact
          end

          get_artifact(artifact.name, artifact.version)
        end

        # Retrieve the artifact from the graph with the matching name and version
        #
        # @param [String] name
        # @param [Gem::Version, #to_s] version
        #
        # @return [Doubleshot::Resolver::GemResolver::Artifact, nil]
        def get_artifact(name, version)
          if @sources.empty?
            @artifacts.fetch(self.class.artifact_key(name, version.to_s), nil)
          else
            artifact = nil
            @sources.any? do |source|
              if spec = source.spec(name, version)
                artifact = Artifact.new(self, name, version)
                spec.runtime_dependencies.each do |dependency|
                  dependency.requirements_list.each do |requirement|
                    artifact.depends(dependency.name, requirement.to_s)
                  end
                end
                true
              end
            end
            artifact
          end
        end

        # Remove the given instance of artifact from the graph
        #
        # @param [Doubleshot::Resolver::GemResolver::Artifact, nil] artifact
        def remove_artifact(artifact)
          if has_artifact?(artifact.name, artifact.version)
            @artifacts.delete(self.class.key_for(artifact))
          end
        end

        # Check if an artifact with a matching name and version is a member of this instance
        # of graph
        #
        # @param [String] name
        # @param [Gem::Version, #to_s] version
        #
        # @return [Boolean]
        def has_artifact?(name, version)
          !get_artifact(name, version).nil?
        end

        # @param [Object] other
        #
        # @return [Boolean]
        def ==(other)
          return false unless other.is_a?(self.class)

          self_artifacts = self.artifacts
          other_artifacts = other.artifacts

          self_dependencies = self_artifacts.inject([]) do |list, artifact|
            list << artifact.dependencies
          end.flatten

          other_dependencies = other_artifacts.inject([]) do |list, artifact|
            list << artifact.dependencies
          end.flatten

          self_artifacts.size == other_artifacts.size &&
          self_dependencies.size == other_dependencies.size &&
          self_artifacts.all? { |artifact| other_artifacts.include?(artifact) } &&
          self_dependencies.all? { |dependency| other_dependencies.include?(dependency) }
        end
        alias_method :eql?, :==

        private

        # @return [Array<Doubleshot::Resolver::GemResolver::Artifact>]
        def artifact_collection
          @artifacts.collect { |name, artifact| artifact }
        end
      end
    end
  end
end