/// Mirrors comment-service's `Comment` entity.
class Comment {
  final String id;
  final String postId;
  final String authorId;
  final String postOwnerId;
  final String? parentCommentId;
  final String content;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool deleted;

  const Comment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.postOwnerId,
    this.parentCommentId,
    required this.content,
    this.createdAt,
    this.updatedAt,
    this.deleted = false,
  });

  bool get isReply => parentCommentId != null;

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
        id: json['id'] as String,
        postId: json['postId'] as String,
        authorId: json['authorId'] as String,
        postOwnerId: json['postOwnerId'] as String,
        parentCommentId: json['parentCommentId'] as String?,
        content: json['content'] as String? ?? '',
        createdAt: json['createdAt'] == null
            ? null
            : DateTime.tryParse(json['createdAt'] as String),
        updatedAt: json['updatedAt'] == null
            ? null
            : DateTime.tryParse(json['updatedAt'] as String),
        deleted: json['deleted'] as bool? ?? false,
      );
}

class CreateCommentRequest {
  final String postId;
  final String content;
  final String? parentCommentId;

  const CreateCommentRequest({
    required this.postId,
    required this.content,
    this.parentCommentId,
  });

  Map<String, dynamic> toJson() => {
        'postId': postId,
        'content': content,
        'parentCommentId': parentCommentId,
      };
}
