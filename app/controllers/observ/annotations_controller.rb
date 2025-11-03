require "csv"

module Observ
  class AnnotationsController < ApplicationController
    before_action :set_annotatable, except: [ :sessions_index, :traces_index, :export ]

  def index
    @annotations = @annotatable.annotations
  end

  def sessions_index
    @sessions = Observ::Session.joins(:annotations).distinct.order(created_at: :desc)
    @annotations = Observ::Annotation.where(annotatable_type: "Observ::Session").includes(:annotatable).order(created_at: :desc)
  end

  def traces_index
    @traces = Observ::Trace.joins(:annotations).distinct.order(created_at: :desc)
    @annotations = Observ::Annotation.where(annotatable_type: "Observ::Trace").includes(:annotatable).order(created_at: :desc)
  end

  def export
    @annotations = case params[:type]
    when "sessions"
      Observ::Annotation.where(annotatable_type: "Observ::Session").includes(:annotatable).order(created_at: :desc)
    when "traces"
      Observ::Annotation.where(annotatable_type: "Observ::Trace").includes(:annotatable).order(created_at: :desc)
    else
      Observ::Annotation.all.includes(:annotatable).order(created_at: :desc)
    end

    respond_to do |format|
      format.csv do
        send_data generate_csv(@annotations),
                  filename: "annotations_#{params[:type] || 'all'}_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv",
                  type: "text/csv"
      end
    end
  end

    def create
      @annotation = @annotatable.annotations.build(annotation_params)

      if @annotation.save
        respond_to do |format|
          format.turbo_stream do
            streams = [
              turbo_stream.prepend(
                "annotations-list",
                partial: "annotations/annotation",
                locals: { annotation: @annotation, annotatable: @annotatable }
              ),
              turbo_stream.replace(
                "annotation-form",
                partial: "annotations/form",
                locals: { annotatable: @annotatable, annotation: @annotatable.annotations.build }
              ),
              turbo_stream.update("annotations-count", @annotatable.annotations.count)
            ]

            empty_state = helpers.content_tag(:div, id: "annotations-empty-state")
            streams << turbo_stream.remove("annotations-empty-state") if @annotatable.annotations.count == 1

            render turbo_stream: streams
          end
          format.html { redirect_back(fallback_location: root_path, notice: "Annotation added successfully.") }
        end
      else
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace(
              "annotation-form",
              partial: "annotations/form",
              locals: { annotatable: @annotatable, annotation: @annotation }
            )
          end
          format.html { redirect_back(fallback_location: root_path, alert: "Failed to add annotation.") }
        end
      end
    end

  def destroy
    @annotation = @annotatable.annotations.find(params[:id])
    @annotation.destroy

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.remove("annotation_#{@annotation.id}")
      end
      format.html { redirect_back(fallback_location: root_path, notice: "Annotation deleted.") }
    end
  end

  private

  def set_annotatable
    if params[:session_id]
      @annotatable = Observ::Session.find(params[:session_id])
    elsif params[:trace_id]
      @annotatable = Observ::Trace.find(params[:trace_id])
    else
      redirect_to root_path, alert: "Invalid resource"
    end
  end

  def annotation_params
    params.require(:annotation).permit(:content)
  end

  def generate_csv(annotations)
    CSV.generate(headers: true) do |csv|
      csv << [ "ID", "Content", "Annotatable Type", "Annotatable ID", "Created At", "Updated At" ]

      annotations.each do |annotation|
        csv << [
          annotation.id,
          annotation.content,
          annotation.annotatable_type,
          annotation.annotatable_id,
          annotation.created_at.iso8601,
          annotation.updated_at.iso8601
        ]
      end
    end
    end
  end
end
