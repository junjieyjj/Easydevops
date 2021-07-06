package org.devops.aws
import com.amazonaws.auth.BasicAWSCredentials
import com.amazonaws.auth.AWSStaticCredentialsProvider
import com.amazonaws.services.ecr.AmazonECRClient
import com.amazonaws.services.ecr.AmazonECRClientBuilder
import com.amazonaws.services.ecr.model.CreateRepositoryRequest
import com.amazonaws.services.ecr.model.CreateRepositoryResult
import com.amazonaws.services.ecr.model.RepositoryAlreadyExistsException
import com.amazonaws.services.ecr.model.GetAuthorizationTokenRequest
import com.amazonaws.services.ecr.model.GetAuthorizationTokenResult

def createRepository(String AWS_ACCESS_KEY_ID, String AWS_SECRET_ACCESS_KEY, String region, String repoName) {
    BasicAWSCredentials credentials = new BasicAWSCredentials(AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
    AmazonECRClient ecrClient = AmazonECRClientBuilder.standard()
            .withCredentials(new AWSStaticCredentialsProvider(credentials))
            .withRegion(region)
            .build()
    GetAuthorizationTokenRequest request = new GetAuthorizationTokenRequest()
    GetAuthorizationTokenResult response = ecrClient.getAuthorizationToken(request)
    //println response.getAuthorizationData()
    token = response.getAuthorizationData().get(0).getAuthorizationToken()
    String[] ecrCreds = new String(token.decodeBase64(), 'UTF-8').split(':')
    result = java.util.Arrays.asList(ecrCreds)

    CreateRepositoryRequest createRequest = new CreateRepositoryRequest().withRepositoryName(repoName)
    //println (createRequest)
    try {
        println "***INFO：AWS ECR Creating Repository ${repoName}."
        CreateRepositoryResult createResult = ecrClient.createRepository(createRequest)
    } catch (RepositoryAlreadyExistsException e) {
        println "***INFO：AWS ECR Repository ${repoName} already exists."
    }

    return result
}
