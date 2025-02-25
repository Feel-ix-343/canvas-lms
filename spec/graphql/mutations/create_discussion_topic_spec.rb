# frozen_string_literal: true

#
# Copyright (C) 2023 - present Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.
#
require "spec_helper"
require_relative "../graphql_spec_helper"
describe Mutations::CreateDiscussionTopic do
  before(:once) do
    course_with_teacher(active_all: true)
  end

  def execute_with_input(create_input, current_user = @teacher)
    mutation_command = <<~GQL
      mutation {
        createDiscussionTopic(input: {
          #{create_input}
        }){
          discussionTopic {
            _id
            contextType
            title
            message
            published
            requireInitialPost
            anonymousState
            isAnonymousAuthor
            delayedPostAt
            lockAt
            allowRating
            onlyGradersCanRate
            todoDate
            podcastEnabled
            podcastHasStudentPosts
            isSectionSpecific
            groupSet {
              _id
            }
            courseSections{
              _id
              name
            }
            attachment{
              _id
            }
          }
          errors {
            attribute
            message
          }
        }
      }
    GQL
    context = { current_user:, request: ActionDispatch::TestRequest.create }
    CanvasSchema.execute(mutation_command, context:)
  end

  def execute_with_input_with_assignment(create_input, current_user = @teacher)
    mutation_command = <<~GQL
      mutation {
        createDiscussionTopic(input: {
          #{create_input}
        }){
          discussionTopic {
            _id
            contextType
            title
            message
            published
            requireInitialPost
            anonymousState
            isAnonymousAuthor
            delayedPostAt
            lockAt
            allowRating
            onlyGradersCanRate
            todoDate
            podcastEnabled
            podcastHasStudentPosts
            isSectionSpecific
            groupSet {
              _id
            }
            courseSections{
              _id
              name
            }
            assignment {
              _id
              name
              pointsPossible
              gradingType
              peerReviews {
                anonymousReviews
                automaticReviews
                count
                enabled
              }
            }
          }
          errors {
            attribute
            message
          }
        }
      }
    GQL
    context = { current_user:, request: ActionDispatch::TestRequest.create }
    CanvasSchema.execute(mutation_command, context:)
  end

  it "successfully creates the discussion topic" do
    context_type = "Course"
    title = "Test Title"
    message = "A message"
    published = false
    require_initial_post = true

    query = <<~GQL
      contextId: "#{@course.id}"
      contextType: "#{context_type}"
      title: "#{title}"
      message: "#{message}"
      published: #{published}
      requireInitialPost: #{require_initial_post}
      anonymousState: "off"
    GQL

    result = execute_with_input(query)
    created_discussion_topic = result.dig("data", "createDiscussionTopic", "discussionTopic")

    expect(result["errors"]).to be_nil
    expect(result.dig("data", "discussionTopic", "errors")).to be_nil

    expect(created_discussion_topic["contextType"]).to eq context_type
    expect(created_discussion_topic["title"]).to eq title
    expect(created_discussion_topic["message"]).to eq message
    expect(created_discussion_topic["published"]).to eq published
    expect(created_discussion_topic["requireInitialPost"]).to be true
    expect(created_discussion_topic["anonymousState"]).to be_nil
    expect(created_discussion_topic["allowRating"]).to be false
    expect(created_discussion_topic["onlyGradersCanRate"]).to be false
    expect(created_discussion_topic["todoDate"]).to be_nil
    expect(created_discussion_topic["podcastEnabled"]).to be false
    expect(created_discussion_topic["podcastHasStudentPosts"]).to be false
    expect(created_discussion_topic["isSectionSpecific"]).to be false
    expect(DiscussionTopic.where("id = #{created_discussion_topic["_id"]}").count).to eq 1
  end

  it "successfully creates an announcement" do
    is_announcement = true
    context_type = "Course"
    title = "Test Title"
    message = "A message"
    published = true
    require_initial_post = true

    query = <<~GQL
      isAnnouncement: #{is_announcement}
      contextId: "#{@course.id}"
      contextType: "#{context_type}"
      title: "#{title}"
      message: "#{message}"
      published: #{published}
      requireInitialPost: #{require_initial_post}
      anonymousState: "off"
    GQL

    result = execute_with_input(query)
    created_announcement = result.dig("data", "createDiscussionTopic", "discussionTopic")

    expect(result["errors"]).to be_nil
    expect(result.dig("data", "discussionTopic", "errors")).to be_nil

    expect(created_announcement["contextType"]).to eq context_type
    expect(created_announcement["title"]).to eq title
    expect(created_announcement["message"]).to eq message
    expect(created_announcement["published"]).to eq published
    expect(created_announcement["requireInitialPost"]).to be true
    expect(created_announcement["anonymousState"]).to be_nil
    expect(created_announcement["allowRating"]).to be false
    expect(created_announcement["onlyGradersCanRate"]).to be false
    expect(created_announcement["todoDate"]).to be_nil
    expect(created_announcement["podcastEnabled"]).to be false
    expect(created_announcement["podcastHasStudentPosts"]).to be false
    expect(Announcement.where("id = #{created_announcement["_id"]}").count).to eq 1
  end

  it "successfully creates a locked announcement" do
    is_announcement = true
    context_type = "Course"
    title = "Test Title"
    message = "A message"
    published = true
    require_initial_post = false
    locked = true

    query = <<~GQL
      isAnnouncement: #{is_announcement}
      contextId: "#{@course.id}"
      contextType: "#{context_type}"
      title: "#{title}"
      message: "#{message}"
      published: #{published}
      requireInitialPost: #{require_initial_post}
      anonymousState: "off"
      locked: #{locked}
    GQL

    result = execute_with_input(query)
    created_announcement = result.dig("data", "createDiscussionTopic", "discussionTopic")

    expect(result["errors"]).to be_nil
    expect(result.dig("data", "discussionTopic", "errors")).to be_nil

    announcement = Announcement.find(created_announcement["_id"])

    expect(announcement.locked_announcement?).to be true
    expect(announcement.workflow_state).to eq "active"
  end

  it "creates an allow_rating discussion topic" do
    query = <<~GQL
      contextId: "#{@course.id}"
      contextType: "Course"
      title: "Allows Ratings"
      message: "You can like this"
      allowRating: true
      published: true
    GQL

    result = execute_with_input(query)
    created_discussion_topic = result.dig("data", "createDiscussionTopic", "discussionTopic")

    expect(result["errors"]).to be_nil
    expect(result.dig("data", "discussionTopic", "errors")).to be_nil
    expect(created_discussion_topic["allowRating"]).to be true
    expect(created_discussion_topic["onlyGradersCanRate"]).to be false
  end

  it "creates an only_graders_can_rate discussion topic" do
    query = <<~GQL
      contextId: "#{@course.id}"
      contextType: "Course"
      title: "Allows Ratings"
      message: "You can like this"
      allowRating: true
      onlyGradersCanRate: true
      published: true
    GQL

    result = execute_with_input(query)
    created_discussion_topic = result.dig("data", "createDiscussionTopic", "discussionTopic")

    expect(result["errors"]).to be_nil
    expect(result.dig("data", "discussionTopic", "errors")).to be_nil
    expect(created_discussion_topic["allowRating"]).to be true
    expect(created_discussion_topic["onlyGradersCanRate"]).to be true
  end

  it "creates a published discussion topic" do
    context_type = "Course"
    title = "Test Title"
    message = "A message"
    published = true
    query = <<~GQL
      contextId: "#{@course.id}"
      contextType: "#{context_type}"
      title: "#{title}"
      message: "#{message}"
      published: #{published}
      anonymousState: "off"
    GQL

    result = execute_with_input(query)
    created_discussion_topic = result.dig("data", "createDiscussionTopic", "discussionTopic")

    expect(result["errors"]).to be_nil
    expect(result.dig("data", "discussionTopic", "errors")).to be_nil
    expect(created_discussion_topic["published"]).to be true
  end

  it "creates a topic with an attachment" do
    attachment = attachment_with_context(@teacher)
    attachment.update!(user: @teacher)

    context_type = "Course"
    title = "Test Title"
    message = "A message"
    published = true
    file_id = attachment.id
    query = <<~GQL
      contextId: "#{@course.id}"
      contextType: "#{context_type}"
      title: "#{title}"
      message: "#{message}"
      published: #{published}
      anonymousState: "off"
      fileId: "#{file_id}"
    GQL

    result = execute_with_input(query)
    created_discussion_topic = result.dig("data", "createDiscussionTopic", "discussionTopic")
    expect(result["errors"]).to be_nil
    expect(result.dig("data", "discussionTopic", "errors")).to be_nil
    expect(created_discussion_topic["attachment"]["_id"]).to eq(attachment.id.to_s)
  end

  it "creates a full_anonymity discussion topic" do
    context_type = "Course"
    title = "Test Title"
    message = "A message"
    published = true
    anonymous_state = "full_anonymity"
    query = <<~GQL
      contextId: "#{@course.id}"
      contextType: "#{context_type}"
      title: "#{title}"
      message: "#{message}"
      published: #{published}
      anonymousState: "#{anonymous_state}"
    GQL

    result = execute_with_input(query)
    created_discussion_topic = result.dig("data", "createDiscussionTopic", "discussionTopic")

    expect(result["errors"]).to be_nil
    expect(result.dig("data", "discussionTopic", "errors")).to be_nil
    expect(created_discussion_topic["anonymousState"]).to eq anonymous_state
  end

  it "allows teachers to still create anonymous discussions even when students cannot" do
    @course.allow_student_anonymous_discussion_topics = false
    @course.save!

    query = <<~GQL
      contextId: "#{@course.id}"
      contextType: "Course"
      title: "Student Anonymous Create"
      message: "this should not return an error"
      published: true
      anonymousState: "full_anonymity"
    GQL

    result = execute_with_input(query, @teacher)
    created_discussion_topic = result.dig("data", "createDiscussionTopic", "discussionTopic")

    expect(result["errors"]).to be_nil
    expect(result.dig("data", "discussionTopic", "errors")).to be_nil
    expect(created_discussion_topic["anonymousState"]).to eq "full_anonymity"
  end

  it "creates a partial_anonymity discussion topic where is_anonymous_author defaults to false" do
    context_type = "Course"
    title = "Test Title"
    message = "A message"
    published = true
    anonymous_state = "partial_anonymity"
    query = <<~GQL
      contextId: "#{@course.id}"
      contextType: "#{context_type}"
      title: "#{title}"
      message: "#{message}"
      published: #{published}
      anonymousState: "#{anonymous_state}"
    GQL

    result = execute_with_input(query)
    created_discussion_topic = result.dig("data", "createDiscussionTopic", "discussionTopic")

    expect(result["errors"]).to be_nil
    expect(result.dig("data", "discussionTopic", "errors")).to be_nil
    expect(created_discussion_topic["anonymousState"]).to eq anonymous_state
    expect(created_discussion_topic["isAnonymousAuthor"]).to be false
  end

  it "creates a partial_anonymity discussion topic with is_anonymous_author set to true" do
    context_type = "Course"
    title = "Test Title"
    message = "A message"
    published = true
    anonymous_state = "partial_anonymity"
    query = <<~GQL
      contextId: "#{@course.id}"
      contextType: "#{context_type}"
      title: "#{title}"
      message: "#{message}"
      published: #{published}
      anonymousState: "#{anonymous_state}"
      isAnonymousAuthor: true
    GQL

    result = execute_with_input(query)
    created_discussion_topic = result.dig("data", "createDiscussionTopic", "discussionTopic")

    expect(result["errors"]).to be_nil
    expect(result.dig("data", "discussionTopic", "errors")).to be_nil
    expect(created_discussion_topic["anonymousState"]).to eq anonymous_state
    expect(created_discussion_topic["isAnonymousAuthor"]).to be true
  end

  it "creates a partial_anonymity discussion topic with is_anonymous_author set to false" do
    context_type = "Course"
    title = "Test Title"
    message = "A message"
    published = true
    anonymous_state = "partial_anonymity"
    query = <<~GQL
      contextId: "#{@course.id}"
      contextType: "#{context_type}"
      title: "#{title}"
      message: "#{message}"
      published: #{published}
      anonymousState: "#{anonymous_state}"
      isAnonymousAuthor: false
    GQL

    result = execute_with_input(query)
    created_discussion_topic = result.dig("data", "createDiscussionTopic", "discussionTopic")

    expect(result["errors"]).to be_nil
    expect(result.dig("data", "discussionTopic", "errors")).to be_nil
    expect(created_discussion_topic["anonymousState"]).to eq anonymous_state
    expect(created_discussion_topic["isAnonymousAuthor"]).to be false
  end

  it "creates a todo_date discussion topic" do
    @course.allow_student_anonymous_discussion_topics = false
    @course.save!

    todo_date = 5.days.from_now.iso8601

    query = <<~GQL
      contextId: "#{@course.id}"
      contextType: "Course"
      title: "TODO Discussion"
      published: true
      anonymousState: "full_anonymity"
      todoDate: "#{todo_date}"
    GQL

    result = execute_with_input(query, @teacher)
    created_discussion_topic = result.dig("data", "createDiscussionTopic", "discussionTopic")

    expect(result["errors"]).to be_nil
    expect(result.dig("data", "discussionTopic", "errors")).to be_nil
    expect(created_discussion_topic["todoDate"]).to eq todo_date
  end

  it "successfully creates the discussion topic with podcast_enabled and podcast_has_student_posts" do
    context_type = "Course"
    title = "Test Title"
    message = "A message"
    published = false
    require_initial_post = true
    podcast_enabled = true
    podcast_has_student_posts = true

    query = <<~GQL
      contextId: "#{@course.id}"
      contextType: "#{context_type}"
      title: "#{title}"
      message: "#{message}"
      published: #{published}
      requireInitialPost: #{require_initial_post}
      anonymousState: "off"
      podcastEnabled: #{podcast_enabled}
      podcastHasStudentPosts: #{podcast_has_student_posts}
    GQL

    result = execute_with_input(query)
    created_discussion_topic = result.dig("data", "createDiscussionTopic", "discussionTopic")

    expect(result["errors"]).to be_nil
    expect(result.dig("data", "discussionTopic", "errors")).to be_nil

    expect(created_discussion_topic["podcastEnabled"]).to be true
    expect(created_discussion_topic["podcastHasStudentPosts"]).to be true
  end

  context "errors" do
    def expect_error(result, message)
      errors = result["errors"] || result.dig("data", "createDiscussionTopic", "errors")
      expect(errors).not_to be_nil
      expect(errors[0]["message"]).to match(/#{message}/)
    end

    context "invalid context" do
      it "returns 'not found' with an incorrect ID" do
        query = <<~GQL
          contextId: "1"
          contextType: "Course"
        GQL
        result = execute_with_input(query)
        expect_error(result, "Not found")
      end

      it "returns 'invalid context' with an incorrect context type" do
        query = <<~GQL
          contextId: "1"
          contextType: "NotAContextType"
        GQL
        result = execute_with_input(query)
        expect_error(result, "Invalid context")
      end
    end

    context "group category id" do
      it "creates parent and child dicussion topics" do
        gc = @course.group_categories.create! name: "foo"
        gc.groups.create! context: @course, name: "baz"
        context_type = "Course"
        title = "Test Title"
        message = "A message"
        published = true

        query = <<~GQL
          contextId: "#{@course.id}"
          contextType: "#{context_type}"
          title: "#{title}"
          message: "#{message}"
          published: #{published}
          groupCategoryId: "#{gc.id}"
        GQL

        result = execute_with_input(query)
        returned_discussion_topic = result.dig("data", "createDiscussionTopic", "discussionTopic")
        expect(result["errors"]).to be_nil
        expect(returned_discussion_topic["groupSet"]["_id"]).to eq gc.id.to_s
        discussion_topics = DiscussionTopic.last(2)
        expect(discussion_topics[0].group_category_id).to eq gc.id
        expect(discussion_topics[1].group_category_id).to eq gc.id
      end

      it "does not create when id is invalid" do
        context_type = "Course"
        title = "Test Title"
        message = "A message"
        published = true

        query = <<~GQL
          contextId: "#{@course.id}"
          contextType: "#{context_type}"
          title: "#{title}"
          message: "#{message}"
          published: #{published}
          groupCategoryId: "foo"
        GQL

        result = execute_with_input(query)
        returned_discussion_topic = result.dig("data", "createDiscussionTopic", "discussionTopic")
        expect(result["errors"]).to be_nil
        expect(returned_discussion_topic["groupSet"]).to be_nil
        discussion_topics = DiscussionTopic.last
        expect(discussion_topics.group_category_id).to be_nil
      end
    end

    context "anonymous_state" do
      it "returns error for anonymous discussions when context is a Group" do
        gc = @course.group_categories.create! name: "foo"
        group = gc.groups.create! context: @course, name: "baz"
        context_type = "Group"
        title = "Test Title"
        message = "A message"
        published = true
        anonymous_state = "partial_anonymity"

        query = <<~GQL
          contextId: "#{group.id}"
          contextType: "#{context_type}"
          title: "#{title}"
          message: "#{message}"
          published: #{published}
          anonymousState: "#{anonymous_state}"
        GQL

        result = execute_with_input(query)
        expect_error(result, "You are not able to create an anonymous discussion in a group")
      end

      it "returns an error for non-teachers without anonymous discussion creation permissions" do
        @course.allow_student_anonymous_discussion_topics = false
        @course.save!
        student_in_course(active_all: true)

        query = <<~GQL
          contextId: "#{@course.id}"
          contextType: "Course"
          title: "Student Anonymous Create"
          message: "this should return an error"
          published: true
          anonymousState: "full_anonymity"
        GQL

        result = execute_with_input(query, @student)
        expect_error(result, "You are not able to create an anonymous discussion")
      end
    end

    context "todo_date" do
      it "returns an error when user has neither manage_content nor manage_course_content_add permissions" do
        todo_date = 5.days.from_now.iso8601
        query = <<~GQL
          contextId: "#{@course.id}"
          contextType: "Course",
          todoDate: "#{todo_date}"
        GQL

        result = execute_with_input(query, @student)
        expect_error(result, "You do not have permission to add this topic to the student to-do list.")
      end
    end
  end

  context "sections" do
    it "successfully creates the discussion topic is_section_specific false" do
      context_type = "Course"
      title = "Test Title"
      message = "A message"
      published = false
      require_initial_post = true
      query = <<~GQL
        contextId: "#{@course.id}"
        contextType: "#{context_type}"
        title: "#{title}"
        message: "#{message}"
        published: #{published}
        requireInitialPost: #{require_initial_post}
        anonymousState: "off"
        specificSections: "all"
      GQL

      result = execute_with_input(query)
      created_discussion_topic = result.dig("data", "createDiscussionTopic", "discussionTopic")

      expect(result["errors"]).to be_nil
      expect(result.dig("data", "discussionTopic", "errors")).to be_nil
      expect(created_discussion_topic["contextType"]).to eq context_type
      expect(created_discussion_topic["title"]).to eq title
      expect(created_discussion_topic["isSectionSpecific"]).to be false
      expect(DiscussionTopic.where("id = #{created_discussion_topic["_id"]}").count).to eq 1
    end

    it "successfully creates the discussion topic is_section_specific true" do
      context_type = "Course"
      title = "Test Title"
      message = "A message"
      published = false
      require_initial_post = true

      section = add_section("Dope Section")
      section2 = add_section("Dope Section 2")

      query = <<~GQL
        contextId: "#{@course.id}"
        contextType: "#{context_type}"
        title: "#{title}"
        message: "#{message}"
        published: #{published}
        requireInitialPost: #{require_initial_post}
        anonymousState: "off"
        specificSections: "#{section.id},#{section2.id}"
      GQL

      result = execute_with_input(query)
      created_discussion_topic = result.dig("data", "createDiscussionTopic", "discussionTopic")

      expect(result["errors"]).to be_nil
      expect(result.dig("data", "discussionTopic", "errors")).to be_nil
      expect(created_discussion_topic["contextType"]).to eq context_type
      expect(created_discussion_topic["title"]).to eq title
      expect(created_discussion_topic["isSectionSpecific"]).to be true
      expect(created_discussion_topic["courseSections"][0]["name"]).to eq("Dope Section")
      expect(created_discussion_topic["courseSections"][1]["name"]).to eq("Dope Section 2")
      expect(DiscussionTopic.where("id = #{created_discussion_topic["_id"]}").count).to eq 1
    end

    it "does not allow creation of disuccions to sections that are not visible to the user" do
      # This teacher does not have permission for section 2
      course2 =  course_factory(active_course: true)
      section1 = @course.course_sections.create!(name: "Section 1")
      section2 = course2.course_sections.create!(name: "Section 2")

      @course.enroll_teacher(@teacher, section: section1, allow_multiple_enrollments: true).accept!
      Enrollment.limit_privileges_to_course_section!(@course, @teacher, true)

      sections = [section1.id, section2.id].join(",")
      context_type = "Course"
      title = "Test Title"
      message = "A message"
      published = false
      require_initial_post = true

      query = <<~GQL
        contextId: "#{@course.id}"
        contextType: "#{context_type}"
        title: "#{title}"
        message: "#{message}"
        published: #{published}
        requireInitialPost: #{require_initial_post}
        anonymousState: "off"
        specificSections: "#{sections}"
      GQL

      result = execute_with_input(query)

      expect(result.dig("data", "createDiscussionTopic", "discussionTopic")).to be_nil
      expect(result.dig("data", "createDiscussionTopic", "errors")[0]["message"]).to eq("You do not have permissions to modify discussion for section(s) #{section2.id}")
    end
  end

  context "delayed_post_at and lock_at" do
    it "successfully creates an unpublished discussion topic with delayed_post_at and lock_at" do
      context_type = "Course"
      title = "Delayed Topic"
      message = "Lorem ipsum..."
      published = false
      require_initial_post = true
      delayed_post_at = 5.days.from_now.iso8601
      lock_at = 10.days.from_now.iso8601

      query = <<~GQL
        contextId: "#{@course.id}"
        contextType: "#{context_type}"
        title: "#{title}"
        message: "#{message}"
        published: #{published}
        requireInitialPost: #{require_initial_post}
        anonymousState: "off"
        delayedPostAt: "#{delayed_post_at}"
        lockAt: "#{lock_at}"
      GQL

      result = execute_with_input(query)
      discussion_topic = result.dig("data", "createDiscussionTopic", "discussionTopic")

      expect(result["errors"]).to be_nil
      expect(result.dig("data", "discussionTopic", "errors")).to be_nil
      expect(discussion_topic["delayedPostAt"]).to eq delayed_post_at
      expect(discussion_topic["lockAt"]).to eq lock_at
      expect(DiscussionTopic.last.workflow_state).to eq "unpublished"
    end

    it "coerces a created published discussion into post_delayed if delayed_post_at is in the future" do
      context_type = "Course"
      title = "Delayed Topic"
      message = "Lorem ipsum..."
      published = true
      require_initial_post = true
      delayed_post_at = 5.days.from_now.iso8601
      lock_at = 10.days.from_now.iso8601

      query = <<~GQL
        contextId: "#{@course.id}"
        contextType: "#{context_type}"
        title: "#{title}"
        message: "#{message}"
        published: #{published}
        requireInitialPost: #{require_initial_post}
        anonymousState: "off"
        delayedPostAt: "#{delayed_post_at}"
        lockAt: "#{lock_at}"
      GQL

      result = execute_with_input(query)
      discussion_topic = result.dig("data", "createDiscussionTopic", "discussionTopic")

      expect(result["errors"]).to be_nil
      expect(result.dig("data", "discussionTopic", "errors")).to be_nil
      expect(discussion_topic["delayedPostAt"]).to eq delayed_post_at
      expect(discussion_topic["lockAt"]).to eq lock_at
      expect(DiscussionTopic.last.workflow_state).to eq "post_delayed"
    end

    it "successfully creates a discussion topic with lock_at only" do
      context_type = "Course"
      title = "Delayed Topic"
      message = "Lorem ipsum..."
      published = false
      require_initial_post = true
      lock_at = 5.days.from_now.iso8601

      query = <<~GQL
        contextId: "#{@course.id}"
        contextType: "#{context_type}"
        title: "#{title}"
        message: "#{message}"
        published: #{published}
        requireInitialPost: #{require_initial_post}
        anonymousState: "off"
        lockAt: "#{lock_at}"
      GQL

      result = execute_with_input(query)
      discussion_topic = result.dig("data", "createDiscussionTopic", "discussionTopic")

      expect(result["errors"]).to be_nil
      expect(result.dig("data", "discussionTopic", "errors")).to be_nil
      expect(discussion_topic["delayedPostAt"]).to be_nil
      expect(discussion_topic["lockAt"]).to eq lock_at
      expect(DiscussionTopic.last.workflow_state).to eq "unpublished"
    end

    it "successfully creates a discussion topic with null delayed_post_at and lock_at" do
      context_type = "Course"
      title = "Topic w/null delayed_post_at and lock_at"
      message = "Lorem ipsum..."
      published = false
      require_initial_post = true
      delayed_post_at = "null"
      lock_at = "null"

      query = <<~GQL
        contextId: "#{@course.id}"
        contextType: "#{context_type}"
        title: "#{title}"
        message: "#{message}"
        published: #{published}
        requireInitialPost: #{require_initial_post}
        anonymousState: "off"
        delayedPostAt: #{delayed_post_at}
        lockAt: #{lock_at}
      GQL

      result = execute_with_input(query)
      discussion_topic = result.dig("data", "createDiscussionTopic", "discussionTopic")

      expect(result["errors"]).to be_nil
      expect(result.dig("data", "discussionTopic", "errors")).to be_nil
      expect(discussion_topic["delayedPostAt"]).to be_nil
      expect(discussion_topic["lockAt"]).to be_nil
    end
  end

  context "graded discussion topics" do
    it "successfully creates a graded discussion topic" do
      context_type = "Course"
      title = "Graded Discussion"
      message = "Lorem ipsum..."
      published = true

      query = <<~GQL
        contextId: "#{@course.id}"
        contextType: "#{context_type}"
        title: "#{title}"
        message: "#{message}"
        published: #{published}
        assignment: {
          courseId: "1",
            name: "#{title}",
            pointsPossible: 15,
            gradingType: percent,
            postToSis: true,
            peerReviews: {
              anonymousReviews: true,
              automaticReviews: true,
              count: 2,
              enabled: true,
              intraReviews: true,
              dueAt: "#{5.days.from_now.iso8601}",
            }
          }
      GQL

      result = execute_with_input_with_assignment(query)
      assignment = Assignment.last
      discussion_topic = result.dig("data", "createDiscussionTopic", "discussionTopic")
      aggregate_failures do
        expect(result.dig("data", "discussionTopic", "errors")).to be_nil
        expect(discussion_topic["assignment"]["name"]).to eq title
        expect(discussion_topic["assignment"]["pointsPossible"]).to eq 15
        expect(discussion_topic["assignment"]["gradingType"]).to eq "percent"
        expect(discussion_topic["assignment"]["peerReviews"]["anonymousReviews"]).to be true
        expect(discussion_topic["assignment"]["peerReviews"]["automaticReviews"]).to be true
        expect(discussion_topic["assignment"]["peerReviews"]["count"]).to eq 2
        expect(discussion_topic["assignment"]["_id"]).to eq assignment.id.to_s
        expect(discussion_topic["_id"]).to eq assignment.discussion_topic.id.to_s
        expect(DiscussionTopic.count).to eq 1
        expect(DiscussionTopic.last.assignment.post_to_sis).to be true
      end
    end

    it "student fails to create graded discussion topic" do
      context_type = "Course"
      title = "Graded Discussion"
      message = "Lorem ipsum..."
      published = true

      query = <<~GQL
        contextId: "#{@course.id}"
        contextType: "#{context_type}"
        title: "#{title}"
        message: "#{message}"
        published: #{published}
        assignment: {
          courseId: "1",
            name: "#{title}",
            pointsPossible: 15,
            gradingType: percent,
            peerReviews: {
              anonymousReviews: true,
              automaticReviews: true,
              count: 2,
              enabled: true,
              intraReviews: true,
              dueAt: "#{5.days.from_now.iso8601}",
            }
          }
      GQL

      student = @course.enroll_student(User.create!, enrollment_state: "active").user
      result = execute_with_input_with_assignment(query, student)
      discussion_topic = result.dig("data", "createDiscussionTopic", "discussionTopic")
      expect(discussion_topic).to be_nil
      expect(result["data"]["createDiscussionTopic"]["errors"][0]["message"]).to eq "You do not have permissions to create assignments in the provided course"
    end
  end
end
