# == Schema Information
#
# Table name: activities
#
#  id           :integer          not null, primary key
#  action       :string(255)
#  subject_id   :integer
#  subject_type :string(255)
#  target_id    :integer
#  target_type  :string(255)
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#

class Activity < ActiveRecord::Base
  attr_accessible :action, :subject_id, :target_id,
			  					:subject_type, :target_type

  after_create :log_notification

  def log_notification

  	# Follow
  	if target_type == "User"
	    Notification.create!({
	    	:owner_id   => target_id,
	    	:owner_type => "User",
				:text       => text,
				:url  			=> url
			})
	  
	  elsif target_type == "Answer" && action = "Up voted"
	  	answer = Answer.find(target_id)

	  	if answer.author_id != subject_id
		  	Notification.create!({
		    	:owner_id   => answer.author_id,
		    	:owner_type => "User",
					:text       => text(answer.author),
					:url  			=> url(answer)
				})
		  end

	  elsif subject_type == "Answer" && action = "Answered"
	  	answer = Answer.find(subject_id)

	  	answer.question.followers.each do |person|
	  		next if person.id == answer.question.author.id
	  		Notification.create!({
		    	:owner_id   => person.id,
		    	:owner_type => "User",
				  :text       => text(answer.author),
			  	:url  			=> url(answer)
			  })
	  	end

	  	return if answer.question.author_id == answer.author.id
	  	Notification.create!({
	    	:owner_id   => answer.question.author_id,
	    	:owner_type => "User",
				:text       => text(answer.author),
				:url  			=> url(answer)
			})
	  end	  	
	end

	def url(sub = subject)
		return nil unless sub
		attrs = {
			:only_path  => true,
			:controller => sub.class.to_s.tableize,
			:action 		=> "show",
			:id 				=> sub
		}

		attrs[:user_id] = sub.author if sub.class == Question

		Rails.application.routes.url_helpers.url_for(attrs)
	end

	def parse_log
		if target_type == "User"			   # Followed
	    return { :text => text, :url => url }

	  elsif target_type == "Answer"   # Upvoted or answered
	  	answer = Answer.find_by_id(target_id)
	  	return empty unless answer

			return {
				:text => text(User.find_by_id(subject_id)),
				:url => url(answer)
			}

		elsif target_type == "Question" # Asked or Followed
			question = Question.find_by_id(target_id)
			return empty unless question

			if action != "Follow"
		  	return { 
		  		:text => text(question.author), 
		  		:url => url(question)
		  	}
		  else
		  	return { 
		  		:text => text(question), 
		  		:url => url(question)
		  	}
		  end
	  end
	end

	def empty
		{ :text => "", :url => "" }
	end

	def subject
		subject_type.camelize.constantize.find(subject_id);
	end

	def target
		target_type.camelize.constantize.find(target_id);
	end	

	def text(sub =  subject)
		return nil unless sub
		target_name = target.name
		obj = target_type == "User" ? target_name : target_type

		"#{sub.name} #{action} #{obj}."
	end

	def post
		case action
			when 'Asked'
				question = Question.find_by_id(target_id)
				post     = { :title => question.title, :body => question.body }	
			when 'Answered'
				question = Question.find_by_id(subject_id)
				answer   = Answer.find_by_id(target_id)
				post     = { :title => question.title, :body => answer.body }	
			when 'Up voted'
				answer   = Answer.find_by_id(target_id)
				post     = { :title => answer.question.title, :body => answer.body }	
			when 'Followed'
				if target_type == "Question"
					question = Question.find_by_id(target_id)
					post   = { :title => question.title, :body => question.body }
				else
					post   = { :title => "", :body => "" }
				end
		end

		post
	end

end